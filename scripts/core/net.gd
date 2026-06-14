class_name Net
extends Node
## Networking layer: ENet host/join plus all RPCs. Game logic stays in main.gd —
## this node only transports. Host is authoritative for all simulation.
##
## Lives at a stable path (Main/Net) on every peer so RPC routing matches.

const PORT := GameConfig.NET_PORT
const MAX_PLAYERS := 4

var main: Node
var active := false  # true when an ENet peer (host or client) is set


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(func(id: int): main.on_peer_connected(id))
	multiplayer.peer_disconnected.connect(func(id: int): main.on_peer_disconnected(id))
	multiplayer.connected_to_server.connect(func(): main.on_join_ok())
	multiplayer.connection_failed.connect(func(): main.on_join_failed())
	multiplayer.server_disconnected.connect(func(): main.on_server_disconnected())


func host_game(port: int = PORT) -> String:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(port, MAX_PLAYERS - 1) != OK:
		return "Could not host on port %d (already in use?)" % port
	multiplayer.multiplayer_peer = peer
	active = true
	return ""


func join_game(ip: String, port: int = PORT) -> String:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(ip, port) != OK:
		return "Invalid address"
	multiplayer.multiplayer_peer = peer
	active = true
	return ""


func lock_session() -> void:
	if active and multiplayer.is_server():
		multiplayer.multiplayer_peer.refuse_new_connections = true


func leave() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	active = false
	_online_role = OnlineRole.NONE
	online_oid = ""
	if Noray.is_connected_to_host():
		Noray.disconnect_from_host()


# --- online: Noray NAT hole-punch + relay fallback -------------------------
# Lets players connect across NATs with no IP:port. The host shares its `oid`
# via the Lobby Registry; clients connect by that oid. Mirrors netfox.noray's
# bootstrapper flow. Once a peer is established the existing host-authoritative
# RPCs run unchanged. See NETWORKING.md §6 and addons/netfox.noray.

enum OnlineRole { NONE, HOST, CLIENT }
var _online_role := OnlineRole.NONE
var _join_oid := ""
var online_oid := ""        # this host's shareable handle once registered
var _noray_wired := false


func _wire_noray() -> void:
	if _noray_wired:
		return
	Noray.on_connect_nat.connect(_on_connect_nat)
	Noray.on_connect_relay.connect(_on_connect_relay)
	_noray_wired = true


# Register this peer with the Noray server (shared by host + client).
func _noray_register() -> String:
	_wire_noray()
	if not Noray.is_connected_to_host():
		var e: int = await Noray.connect_to_host(GameConfig.noray_host(), GameConfig.noray_port())
		if e != OK:
			return "Cannot reach the relay server"
	Noray.register_host()
	# on_pid and on_oid arrive as separate server commands with no guaranteed
	# order, so wait for BOTH before host_online() reads Noray.oid (else we'd
	# announce an empty oid and the lobby would reject it).
	if not await _await_with_timeout(Noray.on_pid, 8.0):
		return "Relay registration timed out"
	if Noray.oid == "" and not await _await_with_timeout(Noray.on_oid, 4.0):
		return "Relay registration timed out"
	var e2: int = await Noray.register_remote()
	if e2 != OK:
		return "Relay registration failed"
	return ""


# Await a signal but give up after `secs`. Returns true if it fired in time.
func _await_with_timeout(sig: Signal, secs: float) -> bool:
	var hit := [false]
	sig.connect(func(_a = null): hit[0] = true, CONNECT_ONE_SHOT)
	var timer := get_tree().create_timer(secs)
	while not hit[0] and timer.time_left > 0.0:
		await get_tree().process_frame
	return hit[0]


# Host online: register with Noray, then listen. On success `online_oid` is set
# (share it via the lobby). Returns "" or a user-facing error string.
func host_online() -> String:
	var err := await _noray_register()
	if err != "":
		return err
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(Noray.local_port, MAX_PLAYERS - 1) != OK:
		return "Could not start the host"
	multiplayer.multiplayer_peer = peer
	multiplayer.server_relay = true
	active = true
	_online_role = OnlineRole.HOST
	online_oid = Noray.oid
	return ""


# Join an online host by its OID. Returns "" once the attempt has started;
# success/failure then arrive via the usual connected_to_server / join_failed.
func join_online(host_oid: String) -> String:
	var err := await _noray_register()
	if err != "":
		return err
	_online_role = OnlineRole.CLIENT
	_join_oid = host_oid
	Noray.connect_nat(host_oid)
	return ""


func _on_connect_nat(address: String, port: int) -> void:
	var err := await _establish(address, port)
	# Client: if the NAT punch failed, fall back to the relay.
	if err != OK and _online_role == OnlineRole.CLIENT:
		Noray.connect_relay(_join_oid)


func _on_connect_relay(address: String, port: int) -> void:
	await _establish(address, port)


# Punch + bring up the ENet peer for whichever role we are.
func _establish(address: String, port: int) -> int:
	if _online_role == OnlineRole.CLIENT:
		var udp := PacketPeerUDP.new()
		udp.bind(Noray.local_port)
		udp.set_dest_address(address, port)
		var herr: int = await PacketHandshake.over_packet_peer(udp)
		udp.close()
		if herr != OK and herr != ERR_BUSY:
			return herr
		var peer := ENetMultiplayerPeer.new()
		var cerr := peer.create_client(address, port, 0, 0, 0, Noray.local_port)
		if cerr != OK:
			return cerr
		multiplayer.multiplayer_peer = peer
		# Don't report success until ENet actually connects — so a connect
		# failure (not just a punch failure) still triggers the relay fallback.
		while peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING:
			await get_tree().process_frame
		if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
			multiplayer.multiplayer_peer = null
			active = false
			return ERR_CANT_CONNECT
		active = true
		return OK
	if _online_role == OnlineRole.HOST:
		# The server peer already exists; just handshake toward the joiner.
		var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
		if peer == null:
			return ERR_UNCONFIGURED
		return await PacketHandshake.over_enet_peer(peer, address, port)
	return ERR_UNAVAILABLE


# --- senders (no-ops when offline/solo) -----------------------------------

func send_config(choices: int, xp_rate: float, enemy_scale: float) -> void:
	if active:
		rpc_run_config.rpc(choices, xp_rate, enemy_scale)


func send_start(ids: PackedInt32Array) -> void:
	if active:
		rpc_start.rpc(ids)


func send_player_state(pid: int, pos: Vector2, facing: Vector2, dashing: bool) -> void:
	if active:
		rpc_player_state.rpc(pid, pos, facing, dashing)


func send_world_state(kind: int, tick: int, chunk: int, total: int, data: PackedFloat32Array) -> void:
	if active:
		rpc_world_state.rpc(kind, tick, chunk, total, data)


func send_hud_state(elapsed: float, xp: int, needed: int, level: int, kills: int, heat: float, difficulty: float) -> void:
	if active:
		rpc_hud_state.rpc(elapsed, xp, needed, level, kills, heat, difficulty)


func send_player_hp(pid: int, hp: int, max_hp: int, downed: bool) -> void:
	if active:
		rpc_player_hp.rpc(pid, hp, max_hp, downed)


func send_revive(pid: int, ratio: float) -> void:
	if active:
		rpc_revive.rpc(pid, ratio)


func send_open_picks(free: bool, starter: bool = false) -> void:
	if active:
		rpc_open_picks.rpc(free, starter)


func submit_choice(pid: int, upgrade_id: String) -> void:
	if active:
		rpc_choose.rpc(pid, upgrade_id)  # call_local: applies everywhere incl. sender
	else:
		main.apply_choice(pid, upgrade_id)


func send_resume() -> void:
	if active:
		rpc_resume.rpc()


func send_set_paused(p: bool) -> void:
	if active:
		rpc_set_paused.rpc(p)


func send_event(type: int, pos: Vector2) -> void:
	if active:
		rpc_event.rpc(type, pos)


func send_end(won: bool, elapsed: float, level: int, kills: int, scores: PackedFloat32Array) -> void:
	if active:
		rpc_end.rpc(won, elapsed, level, kills, scores)


func send_reset() -> void:
	if active:
		rpc_reset.rpc()


# --- RPC receivers ----------------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func rpc_run_config(choices: int, xp_rate: float, enemy_scale: float) -> void:
	main.apply_config(choices, xp_rate, enemy_scale)


@rpc("authority", "call_remote", "reliable")
func rpc_start(ids: PackedInt32Array) -> void:
	main.start_game(Array(ids))


@rpc("any_peer", "call_remote", "unreliable")
func rpc_player_state(pid: int, pos: Vector2, facing: Vector2, dashing: bool) -> void:
	main.apply_player_state(pid, pos, facing, dashing)


@rpc("authority", "call_remote", "unreliable")
func rpc_world_state(kind: int, tick: int, chunk: int, total: int, data: PackedFloat32Array) -> void:
	main.apply_world_state(kind, tick, chunk, total, data)


@rpc("authority", "call_remote", "unreliable")
func rpc_hud_state(elapsed: float, xp: int, needed: int, level: int, kills: int, heat: float, difficulty: float) -> void:
	main.apply_hud_state(elapsed, xp, needed, level, kills, heat, difficulty)


@rpc("authority", "call_remote", "reliable")
func rpc_player_hp(pid: int, hp: int, max_hp: int, downed: bool) -> void:
	main.apply_player_hp(pid, hp, max_hp, downed)


@rpc("authority", "call_remote", "unreliable")
func rpc_revive(pid: int, ratio: float) -> void:
	main.apply_revive(pid, ratio)


@rpc("authority", "call_remote", "reliable")
func rpc_open_picks(free: bool, starter: bool) -> void:
	main.open_picks(free, starter)


@rpc("any_peer", "call_local", "reliable")
func rpc_choose(pid: int, upgrade_id: String) -> void:
	main.apply_choice(pid, upgrade_id)


@rpc("authority", "call_remote", "reliable")
func rpc_resume() -> void:
	main.resume_after_picks()


@rpc("authority", "call_remote", "reliable")
func rpc_set_paused(p: bool) -> void:
	main.apply_pause(p)


@rpc("authority", "call_remote", "reliable")
func rpc_event(type: int, pos: Vector2) -> void:
	main.apply_event(type, pos)


@rpc("authority", "call_remote", "reliable")
func rpc_end(won: bool, elapsed: float, level: int, kills: int, scores: PackedFloat32Array) -> void:
	main.apply_end(won, elapsed, level, kills, scores)


@rpc("authority", "call_remote", "reliable")
func rpc_reset() -> void:
	main.reset_game()
