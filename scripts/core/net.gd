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


# --- senders (no-ops when offline/solo) -----------------------------------

func send_config(choices: int, xp_rate: float, enemy_scale: float) -> void:
	if active:
		rpc_run_config.rpc(choices, xp_rate, enemy_scale)


# Lobby: a client tells the host its chosen name/color/shape (host relays the
# merged roster back out via send_lobby_state). No-op offline (nothing to sync).
func send_lobby_update(pid: int, player_name: String, color_idx: int, shape_idx: int) -> void:
	if active:
		rpc_lobby_update.rpc(pid, player_name, color_idx, shape_idx)


# Host -> everyone: the full lobby roster (peer_id -> {name, color, shape}).
func send_lobby_state(roster: Dictionary) -> void:
	if active:
		rpc_lobby_state.rpc(roster)


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


# Client -> host: "my in-game menu is open, mark me safe (invulnerable + held still)".
func send_set_safe(pid: int, safe: bool) -> void:
	if active:
		rpc_set_safe_flag.rpc(pid, safe)


# Host -> clients: show the cosmetic resume countdown (the real unpause follows via set_paused).
func send_resume_countdown() -> void:
	if active:
		rpc_resume_countdown.rpc()


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


@rpc("any_peer", "call_remote", "reliable")
func rpc_lobby_update(pid: int, player_name: String, color_idx: int, shape_idx: int) -> void:
	main.apply_lobby_update(pid, player_name, color_idx, shape_idx)


@rpc("authority", "call_remote", "reliable")
func rpc_lobby_state(roster: Dictionary) -> void:
	main.apply_lobby_state(roster)


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


@rpc("any_peer", "call_remote", "reliable")
func rpc_set_safe_flag(pid: int, safe: bool) -> void:
	main.apply_set_safe(pid, safe)


@rpc("authority", "call_remote", "reliable")
func rpc_resume_countdown() -> void:
	main.begin_resume_countdown_remote()


@rpc("authority", "call_remote", "reliable")
func rpc_event(type: int, pos: Vector2) -> void:
	main.apply_event(type, pos)


@rpc("authority", "call_remote", "reliable")
func rpc_end(won: bool, elapsed: float, level: int, kills: int, scores: PackedFloat32Array) -> void:
	main.apply_end(won, elapsed, level, kills, scores)


@rpc("authority", "call_remote", "reliable")
func rpc_reset() -> void:
	main.reset_game()
