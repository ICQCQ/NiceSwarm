class_name NorayLobby
extends Node
## Noray NAT-traversal lobby: lets two NAT'd peers rendezvous through a Noray
## relay server instead of needing a directly-reachable host. The game is always
## the CLIENT of the Noray server (outbound TCP/UDP), so this works behind CGNAT —
## see docs/NORAY.md. All the async handshake flow lives here; net.gd keeps thin
## delegators and the direct-IP path (host_game/join_game) untouched as fallback.
##
## Uses the vendored netfox.noray autoloads `Noray` + `PacketHandshake`
## (addons/netfox.noray/). Flow (both roles bootstrap fully):
##   connect_to_host -> register_host -> await on_pid -> register_remote
## Host then exposes its OID (the shareable join code) and listens for incoming
## connect commands; the client calls connect_nat(oid) and both punch a hole over
## the SAME local UDP port (Noray.local_port) that ENet then reuses.

## docker-server Noray relay (DDNS to home IP). Override for local testing via the
## NICESWARM_NORAY_HOST env var (handled in main.gd).
const DEFAULT_HOST := "ns.javis.coffee"
const NORAY_PORT := 8890

## Emitted once we're registered as a host and have our OID (the join code).
signal host_ready(oid: String)
## Emitted on any failure along the way (bad lobby server, handshake/registration
## failure). The UI shows `reason`; the direct-IP path stays available.
signal lobby_failed(reason: String)

var net: Net
var main: Node

# Per-attempt role state so a retry (or the opposite role) starts clean.
var _busy := false
var _client_done := false
var _host_cb := Callable()
var _client_cb := Callable()


## Host a co-op run reachable by OID through the Noray relay. Async; emits
## host_ready(oid) on success or lobby_failed(reason). The ENet server is created
## and `multiplayer_peer` set BEFORE host_ready fires, so a client's handshake
## (which needs peer.host) can never race ahead of the advertised OID.
func host(noray_host := DEFAULT_HOST) -> void:
	if _busy:
		return
	_busy = true
	if not await _bootstrap(noray_host):
		_busy = false
		return
	var peer := ENetMultiplayerPeer.new()
	# Bind ENet to the port Noray registered as our external address — the punch
	# and all game traffic must share this local UDP port.
	var err := peer.create_server(Noray.local_port, Net.MAX_PLAYERS - 1)
	if err != OK:
		lobby_failed.emit("Could not start host (err %d)" % err)
		_busy = false
		return
	multiplayer.multiplayer_peer = peer
	net.active = true
	_host_cb = _on_host_connect
	Noray.on_connect_nat.connect(_host_cb)
	Noray.on_connect_relay.connect(_host_cb)
	host_ready.emit(Noray.oid)


## Join a host by its OID through the Noray relay. Async; the ENet peer is set up
## inside _on_client_connect once Noray brokers the rendezvous, after which the
## existing net.gd multiplayer signals (on_join_ok / connection_failed) drive the
## rest exactly like a direct join.
func join(oid: String, noray_host := DEFAULT_HOST) -> void:
	if _busy:
		return
	# Join codes are uppercase (NORAY_OID_CHARSET); accept any case the player types.
	var code := oid.strip_edges().to_upper()
	if code == "":
		lobby_failed.emit("Enter a join code")
		return
	_busy = true
	_client_done = false
	if not await _bootstrap(noray_host):
		_busy = false
		return
	_client_cb = _on_client_connect
	Noray.on_connect_nat.connect(_client_cb)
	Noray.on_connect_relay.connect(_client_cb)
	Noray.connect_nat(code)


## Drop any Noray signal handlers and reset state. Called from net.leave() so a
## new host/join (or the direct-IP path) never inherits stale connections.
func reset() -> void:
	if _host_cb.is_valid():
		if Noray.on_connect_nat.is_connected(_host_cb):
			Noray.on_connect_nat.disconnect(_host_cb)
		if Noray.on_connect_relay.is_connected(_host_cb):
			Noray.on_connect_relay.disconnect(_host_cb)
		_host_cb = Callable()
	if _client_cb.is_valid():
		if Noray.on_connect_nat.is_connected(_client_cb):
			Noray.on_connect_nat.disconnect(_client_cb)
		if Noray.on_connect_relay.is_connected(_client_cb):
			Noray.on_connect_relay.disconnect(_client_cb)
		_client_cb = Callable()
	if Noray.is_connected_to_host():
		Noray.disconnect_from_host()
	_busy = false
	_client_done = false


## Shared bootstrap for both roles: reach the Noray server, register, and learn our
## OID/PID/local_port. Returns true on success; emits lobby_failed and returns
## false otherwise.
func _bootstrap(noray_host: String) -> bool:
	var err := await Noray.connect_to_host(noray_host, NORAY_PORT)
	if err != OK:
		lobby_failed.emit("Can't reach lobby server %s" % noray_host)
		return false
	Noray.register_host()
	await Noray.on_pid  # OID/PID arrive async right after register-host
	err = await Noray.register_remote()
	if err != OK:
		lobby_failed.emit("Lobby registration failed (err %d)" % err)
		return false
	return true


## Host side: a client wants in. Punch the hole toward it; ENet's own accept runs
## concurrently as the engine polls multiplayer. over_enet blasts for its full
## timeout (it can't receive), so this coroutine lingers a few seconds — harmless,
## and each incoming client gets its own.
func _on_host_connect(address: String, port: int) -> void:
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer == null:
		return
	await PacketHandshake.over_enet(peer.host, address, port)


## Client side: handshake over the registered local port, then ENet-connect to the
## host across the punched path (reusing Noray.local_port as ENet's local bind).
func _on_client_connect(address: String, port: int) -> void:
	if _client_done:
		return
	_client_done = true
	var udp := PacketPeerUDP.new()
	udp.bind(Noray.local_port)
	udp.set_dest_address(address, port)
	var err := await PacketHandshake.over_packet_peer(udp)
	udp.close()
	# ERR_BUSY = we exchanged packets but never saw a full ack; netfox treats this
	# as "probably connectable", so we proceed on OK or BUSY.
	if err != OK and err != ERR_BUSY:
		lobby_failed.emit("NAT handshake failed (err %d)" % err)
		return
	var peer := ENetMultiplayerPeer.new()
	err = peer.create_client(address, port, 0, 0, 0, Noray.local_port)
	if err != OK:
		lobby_failed.emit("Could not connect (err %d)" % err)
		return
	multiplayer.multiplayer_peer = peer
	net.active = true
