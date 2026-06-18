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
const HANDSHAKE_S := 4.0        # per-attempt NAT/relay punch window (< RELAY_FALLBACK_S)
const RELAY_FALLBACK_S := 5.0   # if the NAT punch hasn't landed, ask Noray to relay instead
const JOIN_TIMEOUT_S := 13.0    # overall: give up + report a clear error instead of hanging

## Emitted once we're registered as a host and have our OID (the join code).
signal host_ready(oid: String)
## Emitted on any failure along the way (bad lobby server, handshake/registration
## failure). The UI shows `reason`; the direct-IP path stays available.
signal lobby_failed(reason: String)

var net: Net
var main: Node
var force_relay := false  # skip the NAT punch, go straight to the relay (symmetric-NAT / 5G; diag hook)

# Per-attempt role state so a retry (or the opposite role) starts clean.
var _busy := false
var _connected := false     # client: a peer connection was established (nat or relay)
var _handshaking := false   # client: a punch/handshake is in flight (serialises nat vs relay)
var _attempt := 0           # join attempt id, so a stale watchdog/handshake no-ops
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
	_connected = false
	_handshaking = false
	_attempt += 1
	var attempt := _attempt
	if not await _bootstrap(noray_host):
		_busy = false
		return
	_client_cb = _on_client_connect
	Noray.on_connect_nat.connect(_client_cb)
	Noray.on_connect_relay.connect(_client_cb)
	if force_relay:
		Noray.connect_relay(code)  # symmetric NAT (5G): the punch can't work, relay directly
	else:
		Noray.connect_nat(code)
	_watch_join(attempt, code)  # NAT punch -> relay fallback -> clear error (no silent hang)


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
	_connected = false
	_handshaking = false


## Client watchdog: if the NAT punch hasn't connected within RELAY_FALLBACK_S, ask
## Noray to relay instead (covers symmetric-NAT / LAN-hairpin where direct punch
## fails); if still nothing by JOIN_TIMEOUT_S, surface a clear error rather than
## hanging on "Reaching lobby server". `attempt` guards against a stale run.
func _watch_join(attempt: int, code: String) -> void:
	await get_tree().create_timer(RELAY_FALLBACK_S).timeout
	if _attempt == attempt and _busy and not _connected and not force_relay:
		Noray.connect_relay(code)  # NAT punch didn't land — try the relay (already relaying if forced)
	await get_tree().create_timer(JOIN_TIMEOUT_S - RELAY_FALLBACK_S).timeout
	if _attempt == attempt and _busy and not _connected:
		lobby_failed.emit("Couldn't reach the host. Check the join code, that the host is online, and that host & client use the same lobby server.")
		reset()


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
	# Serialise attempts: fires for both nat and relay (and the host can re-broker),
	# but only one handshake binds Noray.local_port at a time. Once connected we stop.
	if _connected or _handshaking:
		return
	_handshaking = true
	var udp := PacketPeerUDP.new()
	udp.bind(Noray.local_port)
	udp.set_dest_address(address, port)
	var err := await PacketHandshake.over_packet_peer(udp, HANDSHAKE_S)
	udp.close()
	# ERR_BUSY = packets exchanged but no full ack; netfox treats it as connectable.
	# On any other failure, free the lock so the relay fallback (or a re-broker) can
	# try — the watchdog reports the final failure if nothing lands.
	if err != OK and err != ERR_BUSY:
		_handshaking = false
		return
	var peer := ENetMultiplayerPeer.new()
	err = peer.create_client(address, port, 0, 0, 0, Noray.local_port)
	if err != OK:
		_handshaking = false
		return
	multiplayer.multiplayer_peer = peer
	net.active = true
	_connected = true
	_handshaking = false
