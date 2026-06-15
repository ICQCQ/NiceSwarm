class_name Net
extends Node
## Networking layer: ENet host/join plus all RPCs. Game logic stays in main.gd —
## this node only transports. Host is authoritative for all simulation.
##
## Lives at a stable path (Main/Net) on every peer so RPC routing matches.

const PORT := GameConfig.NET_PORT
const MAX_PLAYERS := 4

# ENet's default peer timeout can take up to ~30s to notice a dead connection
# (e.g. the other side's window was closed without a clean disconnect). That
# makes a player look "still connected" long after they're gone, so the host
# won't ghost them and a rejoin attempt gets rejected as "slot still in use".
# Tightening it to a few seconds makes ghosting -- and therefore rejoining --
# responsive on LAN/localhost.
const PEER_TIMEOUT_MS := 3000

var main: Node
var active := false  # true when an ENet peer (host or client) is set


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(func(id: int):
		_tune_peer_timeouts()
		main.on_peer_connected(id))
	multiplayer.peer_disconnected.connect(func(id: int): main.on_peer_disconnected(id))
	multiplayer.connected_to_server.connect(func():
		_tune_peer_timeouts()
		main.on_join_ok())
	multiplayer.connection_failed.connect(func(): main.on_join_failed())
	multiplayer.server_disconnected.connect(func(): main.on_server_disconnected())


## Shorten ENet's disconnect-detection window for every currently-connected
## peer (host: each client; client: the host) so a dropped connection is
## noticed within seconds, not tens of seconds.
func _tune_peer_timeouts() -> void:
	var enet_peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet_peer == null:
		return
	for p in enet_peer.host.get_peers():
		p.set_timeout(PEER_TIMEOUT_MS, PEER_TIMEOUT_MS, PEER_TIMEOUT_MS)


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


# --- mid-game rejoin --------------------------------------------------------

# Client -> host: "is old_pid still a ghosted slot I could rejoin as (or is there
# no run at all -- just a lobby)?" Non-mutating; sent right after a "Join" click
# (only if we have a saved session), before committing to a rejoin request.
func send_rejoin_check(old_pid: int) -> void:
	if active:
		rpc_rejoin_check.rpc(old_pid)


# Host -> the checking client only: whether a rejoin is possible, and whether
# it'd land them back in a run (false) or just the lobby (true).
func send_rejoin_check_result(target: int, available: bool, in_lobby: bool) -> void:
	if active:
		rpc_rejoin_check_result.rpc_id(target, available, in_lobby)


# Client -> host: "I'm the disconnected player previously known as old_pid --
# hand my old character back to me." No-op offline (nothing to rejoin).
func send_rejoin_request(old_pid: int) -> void:
	if active:
		rpc_rejoin_request.rpc(old_pid)


# Host -> the rejoining client only: everything it needs to rebuild its view of
# the run (roster, choice history to replay, current HP per player, run config), plus
# the host's current pause/level-up state so the rejoining client doesn't end up
# running unpaused while everyone else is frozen on a level-up screen. `resuming`
# is true when the host is pausing the whole run for a resume countdown to mark
# this rejoin (everyone -- including this client -- gets the countdown screen).
func send_rejoin_accept(target: int, ids: PackedInt32Array, roster: Dictionary,
		history: Dictionary, hp_snapshot: Dictionary, choices: int, xp_rate: float, enemy_scale: float,
		paused: bool, leveling: bool, free_choice: bool, picks_starter: bool, resuming: bool) -> void:
	if active:
		rpc_rejoin_accept.rpc_id(target, ids, roster, history, hp_snapshot, choices, xp_rate, enemy_scale,
			paused, leveling, free_choice, picks_starter, resuming)


func send_rejoin_reject(target: int, reason: String) -> void:
	if active:
		rpc_rejoin_reject.rpc_id(target, reason)


# Host -> everyone (except the rejoining client, which rebuilds via
# rpc_rejoin_accept): re-key the reconnected player's slot to its new peer id.
func send_player_rejoined(old_pid: int, new_pid: int) -> void:
	if active:
		rpc_player_rejoined.rpc(old_pid, new_pid)


# Host -> everyone: a player's connection dropped or was restored (ghost/un-ghost).
func send_player_connection(pid: int, connected: bool) -> void:
	if active:
		rpc_player_connection.rpc(pid, connected)


# --- late join (a brand-new player joins a session already in progress) ----

# Client -> host: "is a run already in progress, and is there room for me?" Sent
# right after connecting, when we have no saved session to rejoin.
func send_session_check() -> void:
	if active:
		rpc_session_check.rpc()


# Host -> the checking client only: a run is in progress and there's room --
# show the lobby's appearance picker (seeded with the current roster) and a
# "Join Game" button instead of "waiting for the host to start".
func send_late_join_offer(target: int, roster: Dictionary) -> void:
	if active:
		rpc_late_join_offer.rpc_id(target, roster)


# Client -> host: "I've set my look -- splice me into the running game."
func send_late_join_request() -> void:
	if active:
		rpc_late_join_request.rpc()


func send_late_join_reject(target: int, reason: String) -> void:
	if active:
		rpc_late_join_reject.rpc_id(target, reason)


# Host -> the joining client only: everything it needs to build the run (mirrors
# rejoin_accept, minus the resume countdown -- nothing was paused for this).
func send_late_join_accept(target: int, ids: PackedInt32Array, roster: Dictionary,
		history: Dictionary, hp_snapshot: Dictionary, choices: int, xp_rate: float, enemy_scale: float,
		paused: bool, leveling: bool, free_choice: bool, picks_starter: bool) -> void:
	if active:
		rpc_late_join_accept.rpc_id(target, ids, roster, history, hp_snapshot, choices, xp_rate,
			enemy_scale, paused, leveling, free_choice, picks_starter)


# Host -> everyone already in the run (not the joiner, which rebuilds via
# rpc_late_join_accept instead): a brand-new player joined -- add their character.
func send_player_joined(pid: int, player_name: String, color_idx: int, shape_idx: int,
		x: float, y: float, hp: int, max_hp: int) -> void:
	if active:
		rpc_player_joined.rpc(pid, player_name, color_idx, shape_idx, x, y, hp, max_hp)


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


func send_announce(text: String, is_boss: bool) -> void:
	if active:
		rpc_announce.rpc(text, is_boss)


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


@rpc("any_peer", "call_remote", "reliable")
func rpc_rejoin_check(old_pid: int) -> void:
	main.handle_rejoin_check(multiplayer.get_remote_sender_id(), old_pid)


@rpc("authority", "call_remote", "reliable")
func rpc_rejoin_check_result(available: bool, in_lobby: bool) -> void:
	main.on_rejoin_check_result(available, in_lobby)


@rpc("any_peer", "call_remote", "reliable")
func rpc_rejoin_request(old_pid: int) -> void:
	main.handle_rejoin_request(multiplayer.get_remote_sender_id(), old_pid)


@rpc("authority", "call_remote", "reliable")
func rpc_rejoin_accept(ids: PackedInt32Array, roster: Dictionary, history: Dictionary,
		hp_snapshot: Dictionary, choices: int, xp_rate: float, enemy_scale: float,
		paused: bool, leveling: bool, free_choice: bool, picks_starter: bool, resuming: bool) -> void:
	main.rejoin_game(ids, roster, history, hp_snapshot, choices, xp_rate, enemy_scale,
		paused, leveling, free_choice, picks_starter, resuming)


@rpc("authority", "call_remote", "reliable")
func rpc_rejoin_reject(reason: String) -> void:
	main.on_rejoin_rejected(reason)


@rpc("authority", "call_remote", "reliable")
func rpc_player_rejoined(old_pid: int, new_pid: int) -> void:
	main.apply_player_rejoined(old_pid, new_pid)


@rpc("authority", "call_local", "reliable")
func rpc_player_connection(pid: int, connected: bool) -> void:
	main.apply_player_connection(pid, connected)


@rpc("any_peer", "call_remote", "reliable")
func rpc_session_check() -> void:
	main.handle_session_check(multiplayer.get_remote_sender_id())


@rpc("authority", "call_remote", "reliable")
func rpc_late_join_offer(roster: Dictionary) -> void:
	main.on_late_join_offer(roster)


@rpc("any_peer", "call_remote", "reliable")
func rpc_late_join_request() -> void:
	main.handle_late_join_request(multiplayer.get_remote_sender_id())


@rpc("authority", "call_remote", "reliable")
func rpc_late_join_reject(reason: String) -> void:
	main.on_late_join_rejected(reason)


@rpc("authority", "call_remote", "reliable")
func rpc_late_join_accept(ids: PackedInt32Array, roster: Dictionary, history: Dictionary,
		hp_snapshot: Dictionary, choices: int, xp_rate: float, enemy_scale: float,
		paused: bool, leveling: bool, free_choice: bool, picks_starter: bool) -> void:
	main.late_join_game(ids, roster, history, hp_snapshot, choices, xp_rate, enemy_scale,
		paused, leveling, free_choice, picks_starter)


@rpc("authority", "call_remote", "reliable")
func rpc_player_joined(pid: int, player_name: String, color_idx: int, shape_idx: int,
		x: float, y: float, hp: int, max_hp: int) -> void:
	main.apply_player_joined(pid, player_name, color_idx, shape_idx, x, y, hp, max_hp)


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
func rpc_announce(text: String, is_boss: bool) -> void:
	main.show_banner(text, is_boss)


@rpc("authority", "call_remote", "reliable")
func rpc_end(won: bool, elapsed: float, level: int, kills: int, scores: PackedFloat32Array) -> void:
	main.apply_end(won, elapsed, level, kills, scores)


@rpc("authority", "call_remote", "reliable")
func rpc_reset() -> void:
	main.reset_game()
