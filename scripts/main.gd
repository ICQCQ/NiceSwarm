class_name Main
extends Node2D
## NiceSwarm game controller: menu/lobby, world setup, host-authoritative
## simulation (spawning, XP, pickups, revives, win/lose), upgrade flow, HUD.
##
## Multiplayer model: the HOST simulates everything. Clients send their player
## position and upgrade picks; they receive compact world-state snapshots and
## run weapons cosmetically for local feedback (real damage host-only).
## Solo play uses the exact same code path with no network peer.
##
## This node runs PROCESS_MODE_ALWAYS; the World child is PAUSABLE.

const VERSION := "0.9.0"  # shown on the menu; keep in sync with project.godot + export_presets.cfg
# Tunables live in config/game_config.gd — aliased here so existing references work.
const ARENA := GameConfig.ARENA
const WIN_TIME := GameConfig.WIN_TIME
const MAX_WEAPONS := GameConfig.MAX_WEAPONS
const MAX_WEAPON_LEVEL := GameConfig.MAX_WEAPON_LEVEL
const ENEMY_CAP := GameConfig.ENEMY_CAP
const MAX_GEMS := GameConfig.MAX_GEMS
const SPAWN_RING_MIN := GameConfig.SPAWN_RING_MIN
const SPAWN_RING_MAX := GameConfig.SPAWN_RING_MAX
const SPAWN_SAFE_RADIUS := GameConfig.SPAWN_SAFE_RADIUS

const PICKUP_KINDS := ["heart", "bomb", "magnet", "chest"]
const STATE_ENEMIES := 0
const STATE_GEMS := 1
const STATE_PICKUPS := 2
const STATE_TELEGRAPHS := 3
const EVENT_BOMB := 0
const TELEGRAPH_WARN := GameConfig.TELEGRAPH_WARN

const WEAPON_INFO := {
	"bolt": {"name": "Bolt", "learn": "auto-fires at the nearest enemy",
		"level": "+1 projectile, more damage"},
	"orbit": {"name": "Orbit Blades", "learn": "blades circle you, shredding nearby foes",
		"level": "+1 blade, more damage"},
	"nova": {"name": "Nova Pulse", "learn": "periodic blast hits everything around you",
		"level": "bigger radius, more damage"},
	"glaive": {"name": "Boomerang Glaive", "learn": "piercing glaive flies out and returns",
		"level": "extra glaive at Lv2/3, more damage"},
	"lightning": {"name": "Chain Lightning", "learn": "zaps a foe, arcs to nearby enemies",
		"level": "+1 chain, more damage"},
	"flame": {"name": "Flame Cone", "learn": "torches everything in front of you",
		"level": "longer, hotter flames"},
	"mines": {"name": "Proximity Mines", "learn": "drops mines that blast nearby enemies",
		"level": "+1 mine, bigger blasts"},
	"missiles": {"name": "Homing Missiles", "learn": "seeking rockets with splash damage",
		"level": "+1 missile, more damage"},
	"laser": {"name": "Sweep Laser", "learn": "a beam slices circles around you",
		"level": "2nd beam at Lv3, longer beam"},
	"frost": {"name": "Frost Shards", "learn": "piercing shards that chill enemies",
		"level": "+1 shard, more damage"},
	"gravity": {"name": "Gravity Well", "learn": "vortex drags the swarm together",
		"level": "wider, stronger pull"},
	"turret": {"name": "Sentry Turret", "learn": "deployable turret fights for you",
		"level": "longer uptime; 2nd turret at Lv3"},
	"venom": {"name": "Venom Trail", "learn": "leave toxic puddles as you move",
		"level": "bigger, deadlier puddles"},
}

# Stat-upgrade ids (apply_choice) -> label + HUD icon glyph + color.
# Drives the debug panel's stat grid AND the on-screen stat-level icons.
# Order here is the order icons appear on the HUD.
const STAT_INFO := {
	"st_power":    {"label": "Power",    "icon": "P", "color": Color(1.0, 0.45, 0.4)},
	"st_rate":     {"label": "Haste",    "icon": "H", "color": Color(1.0, 0.85, 0.4)},
	"st_area":     {"label": "Area",     "icon": "A", "color": Color(0.55, 0.7, 1.0)},
	"st_duration": {"label": "Duration", "icon": "D", "color": Color(0.6, 1.0, 0.6)},
	"st_speed":    {"label": "Speed",    "icon": "S", "color": Color(0.5, 1.0, 0.9)},
	"st_hp":       {"label": "Vitality", "icon": "♥", "color": Color(1.0, 0.5, 0.6)},
	"st_magnet":   {"label": "Magnet",   "icon": "M", "color": Color(0.8, 0.6, 1.0)},
	"st_dash":     {"label": "Dash",     "icon": "»", "color": Color(1.0, 0.7, 0.45)},
}

# Compact on-screen badge per owned weapon: id -> [3-char code, color hex]. Fusions fall back
# to gold initials of their display name (see _weapon_badge / _fusion_short).
const WEAPON_ICON := {
	"bolt": ["BLT", "9fd0ff"], "orbit": ["ORB", "b0a0ff"], "nova": ["NOV", "c79bff"],
	"glaive": ["GLV", "9fe0c0"], "lightning": ["LTN", "fff07a"], "flame": ["FLM", "ff9a55"],
	"mines": ["MNE", "ffb060"], "missiles": ["MSL", "ff8a6a"], "laser": ["LSR", "ff7a8a"],
	"frost": ["FRS", "8fe0ff"], "gravity": ["GRV", "b58aff"], "turret": ["TRT", "c8d0e0"],
	"venom": ["VNM", "8fdf6a"],
}
const SUP := ["", "¹", "²", "³"]  # superscript weapon level for the HUD badge (max level 3)

# --- session / network ---
var net: Net
var spawner: EnemySpawner
var sim: SimDriver               # headless test harness (NICESWARM_SIM / NICESWARM_FF)
var playing := false
var peer_ids: Array = []        # all peer ids in the run, sorted
var players := {}               # peer_id -> Player
var _score := {}                # peer_id -> {damage, xp, revives, deaths} (host)
var net_scores: Array = []      # end-game scoreboard rows received by clients
var local_id := 1
var auto_start_on_join := false # test hook
var rejoin_pending := false     # we have a saved session: check on the next Join whether it's resumable
var rejoin_old_id := 0          # our peer id in the run we're trying to rejoin

# Persists rejoin_old_id + host address across a full app restart (e.g. the player
# closed the game after disconnecting), so the next "Join" can still resume the run.
const REJOIN_SAVE_PATH := "user://rejoin.cfg"

# Remembers the last server a client successfully joined, so the address/port
# fields are prefilled next launch instead of defaulting to 127.0.0.1.
const LAST_JOIN_SAVE_PATH := "user://last_join.cfg"

# --- profile (name/color/shape, set on the main menu, persisted to disk) ---
var profile_name := "Player"
var profile_color_idx := 0
var profile_shape_idx := 0
const PROFILE_SAVE_PATH := "user://profile.cfg"

# --- lobby (pre-game roster) ---
var lobby_players := {}         # peer_id -> {name, color, shape}; synced host<->clients
var lobby_port := 0             # port we're hosting/connected on, shown in the config column

# --- run config (host sets in the menu, broadcast to all peers at start) ---
const MAX_CHOICES := GameConfig.MAX_CHOICES
var cfg_choices := 3            # upgrade options offered per level-up (2..4)
var cfg_xp_rate := 1.0         # higher = level up faster
var cfg_enemy_scale := 1.0     # higher = tougher/denser enemies
# menu cycler option lists
const CHOICES_OPTS := [2, 3, 4, 5, 6]
const XP_OPTS := [0.5, 1.0, 1.5, 2.0, 3.0, 5.0]
const SCALE_OPTS := [0.75, 1.0, 1.25, 1.5]
var cfg_choices_i := 1
var cfg_xp_i := 1
var cfg_scale_i := 1

# --- shared run state (host simulates; clients receive) ---
var world: Node2D
var elapsed := 0.0
var kills := 0
var level := 1
var xp := 0
var net_xp_needed := 6
var game_over := false
var leveling := false
var free_choice := false
var pending_chests := 0
var picks_starter := false      # current pick is the start-of-run weapon choice
var picked_ids := {}            # host: peers that picked this round
var choice_history := {}        # peer_id -> Array[String] of upgrade ids applied, in order
                                 # (lets a rejoining client replay its way back to its old loadout)
var i_chose := false
var paused_menu := false        # client-side: a host pause froze us (remote "PAUSED" indicator)
var ingame_menu := false        # our own in-game menu/hub is open (opening it pauses the whole run for everyone)
var menu_open_pids := {}         # host-only: pids whose in-game menu is open — the run stays paused while non-empty
const RESUME_COUNTDOWN := 2.0   # seconds of "get ready" before a resume actually un-freezes the run
const HINT_COOP := "WASD move  ·  SPACE/SHIFT dash  ·  revive a downed ally by standing near  ·  ESC pause/menu"
const HINT_SOLO := "WASD move  ·  SPACE/SHIFT dash  ·  ESC pause/menu"

# Threat readout tiers: a named, color-coded band the player can actually parse,
# instead of a bare difficulty float. `at` = difficulty at which the tier begins
# (grounded in real runs: ~6 mid-game, ~16 at 10:00 average, ~22+ when steamrolling).
# Display-only — does NOT affect balance. The last tier's `at` is the "full bar" cap.
const THREAT_TIERS := [
	{"name": "CALM",      "at": 0.0,  "color": Color(0.55, 0.85, 0.65)},
	{"name": "RISING",    "at": 4.0,  "color": Color(0.75, 0.85, 0.5)},
	{"name": "DANGER",    "at": 8.0,  "color": Color(1.0, 0.82, 0.4)},
	{"name": "DEADLY",    "at": 14.0, "color": Color(1.0, 0.55, 0.35)},
	{"name": "NIGHTMARE", "at": 22.0, "color": Color(1.0, 0.35, 0.4)},
]
var countdown_time := 0.0       # >0 while the resume countdown is ticking
var _countdown_done := Callable()  # runs when the countdown reaches zero (the real resume)

# upgrade-category accent colors (option buttons + descriptions)
const CAT_COLORS := {
	"new": Color(0.5, 1.0, 0.6),       # learn a weapon — green
	"level": Color(0.55, 0.8, 1.0),    # level up — blue
	"fuse": Color(1.0, 0.85, 0.3),     # signature new weapon — gold
	"amalgam": Color(1.0, 0.55, 0.3),  # generic combined fusion — orange
	"stat": Color(0.85, 0.85, 0.92),   # passive stat — pale
	"starter": Color(0.5, 1.0, 0.6),
}

# host-only spawning + difficulty state lives in `spawner` (EnemySpawner)
var item_seq := 0
var enemies_by_id := {}
var gems_by_id := {}
var pickups_by_id := {}
var telegraphs_by_id := {}

# --- shared enemy spatial index (perf: built once per physics tick) ---
# Every weapon/projectile used to call get_tree().get_nodes_in_group("enemies") each
# frame (~70 sites), allocating a fresh array of up to ENEMY_CAP and scanning it all —
# an O(emitters * n) cliff late game. Instead we snapshot the group once per tick into
# _enemy_list and bucket it into a uniform grid; emitters query all_enemies() (no alloc)
# or enemies_in_radius()/nearest_enemy_to() (O(local)).
static var instance: Main
const GRID_CELL := 128.0
var _enemy_list: Array[Node] = []   # typed so callers keep Node inference (matches get_nodes_in_group)
var _enemy_grid: Dictionary = {}  # Vector2i cell -> Array[Node]

# sync timers / buffers
var t_player := 0.0
var t_enemy := 0.0
var t_items := 0.0
var t_hud := 0.0
var tick_counter := 0
var state_buffers := {}                       # kind -> {tick: {total, chunks}}
var last_tick := {0: -1, 1: -1, 2: -1, 3: -1}

# --- UI nodes ---
var ui: CanvasLayer
const BANNER_LIFE := 2.6  # boss / mini-boss banner duration (seconds)
var banner_label: Label   # centered boss/mini-boss spawn announcement
var _banner_t := 0.0      # seconds left on the current banner
var hp_label: Label
var timer_label: Label
var level_label: Label
var kills_label: Label
var dash_label: Label
var threat_label: Label
var allies_label: Label
var weapons_label: RichTextLabel
var stats_label: RichTextLabel    # current stat upgrades, shown under the weapon slots
var weapon_tip: RichTextLabel     # hover tooltip: the hovered weapon slot's current stats
var _tip_weapon_id := ""          # weapon_id currently shown in weapon_tip (refreshed while hovered)
var hint_label: Label
var xp_bar: ProgressBar
var arrows: Control
var hud_root: Control
var level_panel: Control
var panel_title: Label
var choice_buttons: Array[Button] = []
var current_choices: Array = []
var end_panel: Control
var end_title: Label
var end_stats: Label
var end_hint: Label
var scoreboard_box: GridContainer
var pause_panel: Control
var pause_loadout: Label
var pause_roster: Label
var ingame_menu_panel: Control   # in-run menu/hub (resume · codex · settings · leave)
var ingame_menu_hint: Label      # hub nav breadcrumb / tab hints
var codex_body: RichTextLabel    # in-hub skill/monster codex content (hidden until opened)
var codex_view := ""             # "" = hub root, "skills", or "monsters"
var countdown_panel: Control     # resume countdown overlay
var countdown_label: Label
var menu_panel: Control
var profile_name_edit: LineEdit
var profile_preview_label: Label
var lobby_panel: Control
var lobby_status_label: Label
var lobby_roster_box: VBoxContainer
var lobby_config_box: VBoxContainer
var lobby_start_btn: Button
var update_check: UpdateCheck
var update_banner: Control      # menu "a newer build is available" notice (hidden until found)
var _update_hash := ""          # sha256 of the newer build, for the Skip-this-version action
var ip_edit: LineEdit
var port_edit: LineEdit
var status_label: Label
var debug: DebugPanel            # F1 debug/testing panel (ui/debug_panel.gd)
var hud: GameHud                 # in-run HUD logic / banners (ui/game_hud.gd)
var gameui: GameUI               # UI tree construction (ui/game_ui.gd)


func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	RenderingServer.set_default_clear_color(Color(0.04, 0.04, 0.07))
	net = Net.new()
	net.name = "Net"
	net.main = self
	add_child(net)
	spawner = EnemySpawner.new()
	spawner.name = "Spawner"
	spawner.main = self
	add_child(spawner)
	spawner.build_type_registry()
	sim = SimDriver.new()
	sim.name = "Sim"
	sim.main = self
	add_child(sim)
	debug = DebugPanel.new()
	debug.name = "Debug"
	debug.main = self
	add_child(debug)
	hud = GameHud.new()
	hud.name = "Hud"
	hud.main = self
	add_child(hud)
	gameui = GameUI.new()
	gameui.name = "UI"
	gameui.main = self
	add_child(gameui)
	_load_profile()
	gameui.build()
	_show_menu("")
	_load_last_join_address()
	_load_rejoin_state()

	# Best-effort: compare our exe against the latest published build and offer an update.
	update_check = UpdateCheck.new()
	update_check.name = "UpdateCheck"
	update_check.update_available.connect(_on_update_available)
	add_child(update_check)
	update_check.check()
	match OS.get_environment("NICESWARM_NET"):  # headless test hooks
		"solo":
			_on_solo_pressed()
		"host":
			auto_start_on_join = true
			_on_host_pressed()
		"join":
			ip_edit.text = "127.0.0.1"
			_on_join_pressed()
	if OS.get_environment("NICESWARM_SIM") != "":
		sim.start()


func is_host() -> bool:
	return multiplayer.is_server()


## Solo run: only the local player is in the run, so co-op-only UI wording
## (party/allies/revive) must not appear. Co-op (host or client) has >1 peer.
func is_solo() -> bool:
	return peer_ids.size() <= 1


func nearest_alive_player(pos: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for p in players.values():
		if p.downed or p.disconnected:  # ghosts are invisible to enemy targeting
			continue
		var d: float = pos.distance_squared_to(p.global_position)
		if d < best_d:
			best_d = d
			best = p
	return best


# --- menu / session flow ----------------------------------------------------

## Single entry point for "return to the main menu" -- always leaves a clean
## slate, regardless of what was on screen (mid-run leave, host disconnect
## while a level-up/pause/end panel was up, failed join, etc.).
func _show_menu(message: String) -> void:
	playing = false
	get_tree().paused = false
	level_panel.visible = false
	end_panel.visible = false
	pause_panel.visible = false
	paused_menu = false
	leveling = false
	_force_close_ingame_menu()
	menu_panel.visible = true
	lobby_panel.visible = false
	lobby_players = {}
	hud_root.visible = false
	status_label.text = message


func _on_update_available(remote_hash: String) -> void:
	_update_hash = remote_hash
	if update_banner != null:
		update_banner.visible = true


func _on_update_get_pressed() -> void:
	OS.shell_open(UpdateCheck.RELEASES_URL)


func _on_update_skip_pressed() -> void:
	if update_check != null and _update_hash != "":
		update_check.mark_skipped(_update_hash)  # don't nag again until a newer build appears
	if update_banner != null:
		update_banner.visible = false


func _apply_menu_config() -> void:
	cfg_choices = CHOICES_OPTS[cfg_choices_i]
	cfg_xp_rate = XP_OPTS[cfg_xp_i]
	cfg_enemy_scale = SCALE_OPTS[cfg_scale_i]


func _on_solo_pressed() -> void:
	net.leave()
	_apply_menu_config()
	lobby_players[1] = {"name": profile_name, "color": profile_color_idx, "shape": profile_shape_idx}
	start_game([1])


func _menu_port() -> int:
	var p := int(port_edit.text.strip_edges())
	if p < 1 or p > 65535:
		p = Net.PORT
		port_edit.text = str(Net.PORT)
	return p


func _on_host_pressed() -> void:
	if net.active:
		net.leave()
	var port := _menu_port()
	var err := net.host_game(port)
	if err != "":
		status_label.text = err
		return
	lobby_port = port
	_show_lobby("Hosting\nPlayers: 1 (you)")


## Join always does the same thing, whether or not we have a saved session to
## resume: connect, then (if rejoin_pending) ask the host -- non-mutating,
## right now on click, never in the background -- whether our old slot is
## still available. on_join_ok/on_rejoin_check_result take it from there.
func _on_join_pressed() -> void:
	if net.active:
		net.leave()
	var port := _menu_port()
	var err := net.join_game(ip_edit.text.strip_edges(), port)
	if err != "":
		status_label.text = err
		return
	lobby_port = port
	status_label.text = "Connecting to %s:%d ..." % [ip_edit.text, port]


func _on_start_pressed() -> void:
	var ids: Array = [1]
	for p in multiplayer.get_peers():
		ids.append(p)
	# Connections stay open after start (unlike a session lock) so a disconnected
	# player can reconnect and rejoin via handle_rejoin_request.
	_apply_menu_config()
	net.send_config(cfg_choices, cfg_xp_rate, cfg_enemy_scale)
	net.send_start(PackedInt32Array(ids))
	start_game(ids)


func apply_config(choices: int, xp_rate: float, enemy_scale: float) -> void:
	cfg_choices = choices
	cfg_xp_rate = xp_rate
	cfg_enemy_scale = enemy_scale
	if lobby_panel != null and lobby_panel.visible:
		_refresh_lobby_config_display()


## Replace the last line of the lobby status label with the current player count
## (host-only). Used on both join and leave so the text reflects the current
## roster instead of accumulating stale "(a player left)" notices.
func _refresh_lobby_player_count() -> void:
	lobby_status_label.text = lobby_status_label.text.rsplit("\n", true, 1)[0] \
		+ "\nPlayers: %d (you + %d)" % [1 + multiplayer.get_peers().size(),
			multiplayer.get_peers().size()]


func on_peer_connected(id: int) -> void:
	if playing:
		return
	if is_host():
		_refresh_lobby_player_count()
		if not lobby_players.has(id):
			lobby_players[id] = {"name": "Player", "color": randi() % Player.COLORS.size(),
				"shape": randi() % Player.SHAPES.size()}
		net.send_lobby_state(lobby_players)
		_refresh_lobby_roster()
		if auto_start_on_join:
			get_tree().create_timer(0.5).timeout.connect(_on_start_pressed)


func on_peer_disconnected(id: int) -> void:
	if not playing:
		lobby_players.erase(id)
		_refresh_lobby_roster()
		if is_host():
			_refresh_lobby_player_count()
			net.send_lobby_state(lobby_players)
		return
	# Mid-game: keep the player's character (with its weapons/levels intact) in
	# place, ghosted and invulnerable, so they can rejoin and pick up where they
	# left off instead of being removed from the run.
	var p: Player = players.get(id)
	if p != null:
		p.disconnected = true
	if is_host():
		if p != null:
			p.safe = true
		if leveling and not picked_ids.has(id):
			picked_ids[id] = true  # don't block "wait for all" on an absent player
			_check_all_picked()
		net.send_player_connection(id, false)


func on_join_ok() -> void:
	local_id = multiplayer.get_unique_id()
	_save_last_join_address(ip_edit.text.strip_edges(), lobby_port)
	if rejoin_pending:
		# We have a saved session -- ask the host (non-mutating, right now on this
		# connection) whether it's still available before committing to anything.
		net.send_rejoin_check(rejoin_old_id)
		return
	# Send our profile (set on the main menu) and ask whether a run is already in
	# progress. If so the host splices us straight into it (late_join_game, no
	# lobby); otherwise it adds us to the lobby roster (apply_lobby_state shows
	# the lobby once the roster arrives).
	net.send_session_check(profile_name, profile_color_idx, profile_shape_idx)
	status_label.text = "Connected! Checking the session..."


func on_join_failed() -> void:
	net.leave()
	_show_menu("Could not connect. Check the IP and that the host is running.")


func on_server_disconnected() -> void:
	var was_playing := playing
	var old_id := local_id
	net.leave()
	_clear_world()
	if was_playing:
		rejoin_old_id = old_id
		rejoin_pending = true
		_save_rejoin_state(old_id, ip_edit.text.strip_edges(), lobby_port)
		_show_menu("")
	else:
		_show_menu("Host disconnected.")


## Host's (non-mutating) answer to rpc_rejoin_check: is our old slot still ghosted
## and waiting (in-game), or does the host have no run at all (lobby)?
func on_rejoin_check_result(available: bool, in_lobby: bool) -> void:
	if not available:
		net.leave()
		rejoin_pending = false
		_clear_rejoin_state()
		_show_menu("Could not rejoin -- that session has already started without you.")
		return
	if in_lobby:
		rejoin_pending = false
		_clear_rejoin_state()  # the old run is gone -- this is a fresh lobby join now
		_show_lobby("Connected! Waiting for the host to start...")
		return
	net.send_rejoin_request(rejoin_old_id)
	status_label.text = "Reconnected, restoring your character..."


## Host: non-mutating answer to "can new_id rejoin as old_pid?" -- the rejoining
## client checks this on its "Join" click before committing to a rejoin request.
func handle_rejoin_check(new_id: int, old_pid: int) -> void:
	if not is_host():
		return
	if not playing:
		net.send_rejoin_check_result(new_id, true, true)  # no run -- but the lobby is open
		return
	var p: Player = players.get(old_pid)
	net.send_rejoin_check_result(new_id, p != null and p.disconnected, false)


## Host: a freshly (re)connected peer `new_id` claims to be the disconnected
## player previously known as `old_pid`. If that slot is still here and marked
## disconnected, hand it over -- the Player node (with its weapons/levels intact)
## is reused as-is, so the rejoining client just needs to catch up on choices
## made while it was away.
func handle_rejoin_request(new_id: int, old_pid: int) -> void:
	if not is_host():
		return
	if not playing:
		net.send_rejoin_reject(new_id, "The host left the run.")
		return
	var p: Player = players.get(old_pid)
	if p == null or not p.disconnected:
		net.send_rejoin_reject(new_id, "Could not rejoin -- that player slot is no longer available.")
		return
	players.erase(old_pid)
	players[new_id] = p
	p.peer_id = new_id
	p.disconnected = false
	p.safe = false
	var i := peer_ids.find(old_pid)
	if i != -1:
		peer_ids[i] = new_id
	peer_ids.sort()
	_rekey(lobby_players, old_pid, new_id)
	_rekey(_score, old_pid, new_id)
	_rekey(choice_history, old_pid, new_id)
	_rekey(picked_ids, old_pid, new_id)
	if leveling:
		# A round in progress now has a real screen to show this client (below) --
		# don't count their (possibly ghost-skipped) old entry as already picked.
		picked_ids.erase(new_id)
	var hp_snapshot := {}
	for pid in players:
		var pl: Player = players[pid]
		hp_snapshot[pid] = [pl.hp, pl.max_hp, pl.downed, pl.global_position.x, pl.global_position.y]
	net.send_player_rejoined(old_pid, new_id)
	# Mark a reconnect with a shared "resuming" countdown -- but only when play was
	# actually running (not mid-level-up, not already paused for some other reason).
	var resuming := not leveling and not get_tree().paused
	if resuming:
		get_tree().paused = true
		net.send_set_paused(true)
	net.send_rejoin_accept(new_id, PackedInt32Array(peer_ids), lobby_players, choice_history,
		hp_snapshot, cfg_choices, cfg_xp_rate, cfg_enemy_scale,
		get_tree().paused, leveling, free_choice, picks_starter, resuming)
	if resuming:
		net.send_resume_countdown()
		_begin_resume_countdown(func() -> void:
			get_tree().paused = false
			net.send_set_paused(false))


## Other clients: the host just handed the disconnected slot `old_pid` over to
## `new_pid` -- re-key local bookkeeping so the (still-alive) Player node is found
## under its new id. No-op for the rejoining client itself (it rebuilds its whole
## view via rejoin_game instead).
func apply_player_rejoined(old_pid: int, new_pid: int) -> void:
	if not players.has(old_pid):
		return
	var p: Player = players[old_pid]
	players.erase(old_pid)
	players[new_pid] = p
	p.peer_id = new_pid
	p.disconnected = false
	p.safe = false
	p.is_local = new_pid == local_id
	var i := peer_ids.find(old_pid)
	if i != -1:
		peer_ids[i] = new_pid
	peer_ids.sort()
	_rekey(lobby_players, old_pid, new_pid)
	_rekey(_score, old_pid, new_pid)
	_rekey(choice_history, old_pid, new_pid)
	_rekey(picked_ids, old_pid, new_pid)


func _rekey(d: Dictionary, old_key, new_key) -> void:
	if old_key == new_key or not d.has(old_key):
		return
	d[new_key] = d[old_key]
	d.erase(old_key)


func on_rejoin_rejected(reason: String) -> void:
	net.leave()
	rejoin_pending = false
	_clear_rejoin_state()
	_show_menu(reason)


# --- late join (a brand-new player joins a session already in progress) -----

## Host: a freshly connected peer sent its profile (name/color/shape, set on its
## main menu) and asked whether a run is already underway. If not, add it to the
## lobby roster as usual. If a run IS in progress, skip the lobby entirely and
## splice a brand-new Player straight into the running game using that profile.
func handle_session_check(new_id: int, player_name: String, color_idx: int, shape_idx: int) -> void:
	if not is_host():
		return
	var info := {"name": player_name, "color": color_idx % Player.COLORS.size(),
		"shape": shape_idx % Player.SHAPES.size()}
	lobby_players[new_id] = info
	if not playing:
		_refresh_lobby_player_count()
		net.send_lobby_state(lobby_players)
		_refresh_lobby_roster()
		if auto_start_on_join:
			get_tree().create_timer(0.5).timeout.connect(_on_start_pressed)
		return
	if players.has(new_id):
		return  # already joined -- ignore a duplicate request
	if peer_ids.size() >= Net.MAX_PLAYERS:
		net.send_late_join_reject(new_id, "The party is full.")
		return
	# If the host is mid "resuming..." countdown, the world is about to unpause via
	# a broadcast this brand-new connection could race with -- wait for it to settle
	# so the late-joiner always arrives in a stable paused/running state instead of
	# getting stuck frozen forever.
	while countdown_time > 0.0:
		await get_tree().create_timer(0.1).timeout
		if not is_host() or not playing:
			return  # host stopped/left mid-wait
		if players.has(new_id):
			return  # already joined via a retried session_check
	# Freeze the run for everyone while the late-joiner is spliced in -- gives the
	# new Player node a moment to build/replay before anyone moves around it, and
	# a stable "paused" snapshot is simplest for the joiner to mirror. A short
	# shared "resuming..." countdown un-freezes everyone together afterwards.
	var was_running := not get_tree().paused
	if was_running:
		get_tree().paused = true
		net.send_set_paused(true)
	var spawn_pos := _late_join_spawn_pos()
	var p := _make_player_node(new_id, info, spawn_pos)
	p.add_weapon("bolt")
	_register_player(p)
	peer_ids.append(new_id)
	peer_ids.sort()
	# Record the starter grant so a *later* late-joiner's history replay also
	# gives this player their bolt (apply_player_joined grants it directly to
	# everyone already here).
	choice_history[new_id] = ["learn_bolt"]

	var hp_snapshot := {}
	for pid in players:
		var pl: Player = players[pid]
		hp_snapshot[pid] = [pl.hp, pl.max_hp, pl.downed, pl.global_position.x, pl.global_position.y]

	net.send_late_join_accept(new_id, PackedInt32Array(peer_ids), lobby_players, choice_history,
		hp_snapshot, cfg_choices, cfg_xp_rate, cfg_enemy_scale,
		get_tree().paused, leveling, free_choice, picks_starter)
	net.send_player_joined(new_id, p.player_name, p.color_idx, p.shape_idx,
		spawn_pos.x, spawn_pos.y, p.hp, p.max_hp)
	if OS.get_environment("NICESWARM_NET") != "":
		print("[test] late join accepted id=%d peers=%s" % [new_id, str(peer_ids)])
	if was_running:
		net.send_resume_countdown()
		_begin_resume_countdown(func() -> void:
			get_tree().paused = false
			net.send_set_paused(false))


## Client: the host couldn't splice us into the running game (party full).
func on_late_join_rejected(reason: String) -> void:
	net.leave()
	_show_menu(reason)


## Host: a safe-ish spawn point for a brand-new mid-run player -- next to an
## existing ally (so they're not dropped into the swarm alone), or the arena
## center if (somehow) no one is alive yet.
func _late_join_spawn_pos() -> Vector2:
	var anchor: Node2D = nearest_alive_player(Vector2.ZERO)
	var base := anchor.global_position if anchor != null else Vector2.ZERO
	return base + Vector2.from_angle(randf() * TAU) * 50.0


## We asked to late-join and the host accepted: rebuild the world for the
## current roster (mirrors rejoin_game), replay every choice made so far so
## existing players' weapons/levels match the host, then grant ourselves the
## starting Bolt weapon since we missed the run's starter pick.
func late_join_game(ids: PackedInt32Array, roster: Dictionary, history: Dictionary,
		hp_snapshot: Dictionary, choices: int, xp_rate: float, enemy_scale: float,
		host_paused: bool, host_leveling: bool, host_free_choice: bool, host_picks_starter: bool) -> void:
	peer_ids = Array(ids)
	peer_ids.sort()
	lobby_players = roster
	cfg_choices = choices
	cfg_xp_rate = xp_rate
	cfg_enemy_scale = enemy_scale
	local_id = multiplayer.get_unique_id()
	_reset_run_state()
	_build_world(false)
	for pid in history:
		for id in history[pid]:
			apply_choice(int(pid), id, true)
	choice_history = history.duplicate(true)
	for pid in hp_snapshot:
		var pl: Player = players.get(int(pid))
		if pl == null:
			continue
		var snap: Array = hp_snapshot[pid]
		pl.hp = int(snap[0])
		pl.max_hp = int(snap[1])
		pl.downed = bool(snap[2])
		pl.global_position = Vector2(float(snap[3]), float(snap[4]))
		pl.net_target = pl.global_position
		pl.health_changed.emit(pl.hp, pl.max_hp)
	var me: Player = players.get(local_id)
	if me != null and me.weapons.is_empty() and not host_picks_starter:
		me.add_weapon("bolt")
	playing = true
	# A late-joiner can rejoin too, if they disconnect later.
	_save_rejoin_state(local_id, ip_edit.text.strip_edges(), lobby_port)
	menu_panel.visible = false
	lobby_panel.visible = false
	hud_root.visible = true
	# Match the run's current pause/level-up state, same as a rejoin -- if a
	# pick is open or the host is paused, we should see that too.
	if host_leveling:
		open_picks(host_free_choice, host_picks_starter)
	elif host_paused:
		get_tree().paused = true
	if OS.get_environment("NICESWARM_NET") != "":
		print("[test] late_join_game peers=%s local=%d weapons=%d" \
			% [str(peer_ids), local_id, (me.weapons.size() if me != null else -1)])


## Everyone already in the run (not the joiner, which rebuilds via
## late_join_game instead): the host added a brand-new player -- create their
## Player node here too so they show up immediately.
func apply_player_joined(pid: int, player_name: String, color_idx: int, shape_idx: int,
		x: float, y: float, hp: int, max_hp: int) -> void:
	if not playing or players.has(pid):
		return
	lobby_players[pid] = {"name": player_name, "color": color_idx, "shape": shape_idx}
	peer_ids.append(pid)
	peer_ids.sort()
	var p := _make_player_node(pid, lobby_players[pid], Vector2(x, y))
	p.add_weapon("bolt")
	p.hp = hp
	p.max_hp = max_hp
	_register_player(p)
	p.health_changed.emit(p.hp, p.max_hp)
	if OS.get_environment("NICESWARM_NET") != "":
		print("[test] apply_player_joined id=%d peers=%s" % [pid, str(peer_ids)])


## Remember rejoin_old_id + the host address on disk so "Rejoin" still works
## after the player fully closes and relaunches the game.
func _save_rejoin_state(old_id: int, ip: String, port: int) -> void:
	var f := FileAccess.open(REJOIN_SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_var({"old_id": old_id, "ip": ip, "port": port})


## Called once at startup: if we have a saved rejoin from a previous session,
## restore rejoin_pending/rejoin_old_id and pre-fill the host address so the
## next "Join" checks whether it's resumable.
func _load_rejoin_state() -> void:
	if OS.get_environment("NICESWARM_NET") != "" or OS.get_environment("NICESWARM_TEST") != "":
		return  # headless test runs: ignore any stale save from interactive play
	if not FileAccess.file_exists(REJOIN_SAVE_PATH):
		return
	var f := FileAccess.open(REJOIN_SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = f.get_var()
	if typeof(data) != TYPE_DICTIONARY or not data.has("old_id"):
		return
	rejoin_old_id = int(data["old_id"])
	rejoin_pending = true
	if data.has("ip"):
		ip_edit.text = str(data["ip"])
	if data.has("port"):
		port_edit.text = str(int(data["port"]))


func _clear_rejoin_state() -> void:
	var da := DirAccess.open("user://")
	if da != null and da.file_exists("rejoin.cfg"):
		da.remove("rejoin.cfg")


## Remember the address/port a client just successfully connected to, so the
## join fields are prefilled with it next launch.
func _save_last_join_address(ip: String, port: int) -> void:
	var f := FileAccess.open(LAST_JOIN_SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_var({"ip": ip, "port": port})


## Called once at startup: prefill the join address/port fields from the last
## server a client successfully connected to (defaults stay as-is if none saved).
func _load_last_join_address() -> void:
	if OS.get_environment("NICESWARM_NET") != "" or OS.get_environment("NICESWARM_TEST") != "":
		return  # headless test runs: ignore any stale save from interactive play
	if not FileAccess.file_exists(LAST_JOIN_SAVE_PATH):
		return
	var f := FileAccess.open(LAST_JOIN_SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = f.get_var()
	if typeof(data) != TYPE_DICTIONARY:
		return
	if data.has("ip"):
		ip_edit.text = str(data["ip"])
	if data.has("port"):
		port_edit.text = str(int(data["port"]))


## Save the main-menu profile (name/color/shape) so it persists across launches.
func _save_profile() -> void:
	var f := FileAccess.open(PROFILE_SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_var({"name": profile_name, "color": profile_color_idx, "shape": profile_shape_idx})


## Called once at startup, before the menu is built, so the profile panel shows
## the saved name/color/shape immediately.
func _load_profile() -> void:
	if not FileAccess.file_exists(PROFILE_SAVE_PATH):
		return
	var f := FileAccess.open(PROFILE_SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = f.get_var()
	if typeof(data) != TYPE_DICTIONARY:
		return
	profile_name = String(data.get("name", profile_name))
	profile_color_idx = int(data.get("color", profile_color_idx)) % Player.COLORS.size()
	profile_shape_idx = int(data.get("shape", profile_shape_idx)) % Player.SHAPES.size()


## Rejoining client: the host accepted our rejoin request. Rebuild the world for
## the current roster, then replay every choice made since the run started (ours
## included) so weapons/levels/stat upgrades come back exactly as they were, and
## restore each player's current HP from the host's snapshot.
func rejoin_game(ids: PackedInt32Array, roster: Dictionary, history: Dictionary,
		hp_snapshot: Dictionary, choices: int, xp_rate: float, enemy_scale: float,
		host_paused: bool, host_leveling: bool, host_free_choice: bool, host_picks_starter: bool,
		resuming: bool) -> void:
	peer_ids = Array(ids)
	peer_ids.sort()
	lobby_players = roster
	cfg_choices = choices
	cfg_xp_rate = xp_rate
	cfg_enemy_scale = enemy_scale
	local_id = multiplayer.get_unique_id()
	_reset_run_state()
	_build_world(false)
	for pid in history:
		for id in history[pid]:
			apply_choice(int(pid), id, true)
	choice_history = history.duplicate(true)
	for pid in hp_snapshot:
		var pl: Player = players.get(int(pid))
		if pl == null:
			continue
		var info: Array = hp_snapshot[pid]
		pl.hp = int(info[0])
		pl.max_hp = int(info[1])
		pl.downed = bool(info[2])
		# _build_world placed everyone on a fresh spawn-circle near the origin --
		# snap back to where they actually are in the run (the ghost's last known
		# position for us, current positions for everyone else).
		pl.global_position = Vector2(float(info[3]), float(info[4]))
		pl.net_target = pl.global_position
		pl.health_changed.emit(pl.hp, pl.max_hp)
	playing = true
	rejoin_pending = false
	# Re-save under our new peer id, so a later disconnect+close can rejoin again.
	_save_rejoin_state(local_id, ip_edit.text.strip_edges(), lobby_port)
	menu_panel.visible = false
	lobby_panel.visible = false
	hud_root.visible = true
	# Match the run's current pause/level-up state -- otherwise we'd run unpaused
	# while everyone else is frozen on a level-up screen (our world keeps moving,
	# theirs doesn't, so they appear frozen to us).
	if host_leveling:
		open_picks(host_free_choice, host_picks_starter)
	elif host_paused:
		get_tree().paused = true
		if resuming:
			# The host paused everyone for a shared "resuming..." countdown to mark our
			# reconnect -- show it here too (the host's set_paused(false) afterward
			# unpauses us via apply_pause, same as everyone else).
			paused_menu = true
			_begin_resume_countdown(Callable())


# --- profile (main menu: name/color/shape, used whenever we host/join/solo) --

## Local player edited their name/color/shape on the main menu: store it,
## persist it to disk, refresh the preview, and (if connected to a lobby) sync
## it -- clients ask the host to relay; the host rebroadcasts the full roster.
func _on_profile_appearance_changed() -> void:
	var player_name := profile_name_edit.text.strip_edges().left(16)
	if player_name == "":
		player_name = "Player"
	profile_name_edit.text = player_name
	profile_name = player_name
	_save_profile()
	_refresh_profile_preview()
	if lobby_players.has(local_id):
		lobby_players[local_id] = {"name": profile_name, "color": profile_color_idx, "shape": profile_shape_idx}
		_refresh_lobby_roster()
	if not net.active:
		return
	if is_host():
		net.send_lobby_state(lobby_players)
	else:
		net.send_lobby_update(local_id, profile_name, profile_color_idx, profile_shape_idx)


func _on_profile_color_pressed() -> void:
	profile_color_idx = (profile_color_idx + 1) % Player.COLORS.size()
	_on_profile_appearance_changed()


func _on_profile_shape_pressed() -> void:
	profile_shape_idx = (profile_shape_idx + 1) % Player.SHAPES.size()
	_on_profile_appearance_changed()


func _refresh_profile_preview() -> void:
	if profile_preview_label == null:
		return
	var shape: String = Player.SHAPES[profile_shape_idx % Player.SHAPES.size()]
	profile_preview_label.text = Player.SHAPE_GLYPHS.get(shape, "*")
	profile_preview_label.add_theme_color_override("font_color",
		Player.COLORS[profile_color_idx % Player.COLORS.size()])


# --- lobby (pre-game roster) -------------------------------------------------

## Shows the lobby panel (roster + game config) after hosting, or after a join
## that landed in a lobby rather than a running game. `status` is the
## connection-state line shown at top. Appearance is set on the main menu
## (profile_name/profile_color_idx/profile_shape_idx), not here.
func _show_lobby(status: String) -> void:
	rejoin_pending = false
	menu_panel.visible = false
	lobby_panel.visible = true
	hud_root.visible = false
	local_id = multiplayer.get_unique_id()
	lobby_players[local_id] = {"name": profile_name, "color": profile_color_idx, "shape": profile_shape_idx}
	lobby_status_label.text = status
	lobby_start_btn.visible = is_host()
	_refresh_lobby_roster()
	_refresh_lobby_config_display()
	if net.active and not is_host():
		net.send_lobby_update(local_id, profile_name, profile_color_idx, profile_shape_idx)


func _on_lobby_leave_pressed() -> void:
	net.leave()
	_show_menu("")


## Client/host -> host: a peer's appearance changed. Host merges it into the
## roster and rebroadcasts the full roster to everyone (incl. the sender).
func apply_lobby_update(pid: int, player_name: String, color_idx: int, shape_idx: int) -> void:
	lobby_players[pid] = {"name": player_name, "color": color_idx, "shape": shape_idx}
	_refresh_lobby_roster()
	if is_host():
		net.send_lobby_state(lobby_players)


## Host -> everyone: replace our view of the lobby roster. The first roster we
## receive after connecting (while still on the main menu, not playing) is what
## tells us the host's run hasn't started yet -- show the lobby now.
func apply_lobby_state(roster: Dictionary) -> void:
	lobby_players = roster.duplicate(true)
	_refresh_lobby_roster()
	if not playing and not lobby_panel.visible:
		_show_lobby("Connected! Waiting for the host to start...")


func _refresh_lobby_roster() -> void:
	if lobby_roster_box == null:
		return
	for c in lobby_roster_box.get_children():
		c.queue_free()
	var pids := lobby_players.keys()
	pids.sort()
	for pid in pids:
		var info: Dictionary = lobby_players[pid]
		var shape: String = Player.SHAPES[int(info.get("shape", 0)) % Player.SHAPES.size()]
		var tag := "  [HOST]" if pid == 1 else ""
		var row := PanelContainer.new()
		if pid == local_id:  # highlight your own row instead of an inline "(you)" tag
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(1.0, 1.0, 1.0, 0.12)
			sb.set_corner_radius_all(6)
			sb.content_margin_left = 8.0
			sb.content_margin_right = 8.0
			sb.content_margin_top = 2.0
			sb.content_margin_bottom = 2.0
			row.add_theme_stylebox_override("panel", sb)
		var l := Label.new()
		l.text = "%s  %s%s" % [Player.SHAPE_GLYPHS.get(shape, "*"), info.get("name", "Player"), tag]
		l.add_theme_font_size_override("font_size", 20)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_color",
			Player.COLORS[int(info.get("color", 0)) % Player.COLORS.size()])
		row.add_child(l)
		lobby_roster_box.add_child(row)


## Host: editable cyclers that broadcast on change. Clients: read-only labels,
## refreshed whenever apply_config() receives the host's current values.
func _refresh_lobby_config_display() -> void:
	if lobby_config_box == null:
		return
	for c in lobby_config_box.get_children():
		c.queue_free()
	_make_config_label(lobby_config_box, "Port", str(lobby_port))
	if is_host():
		_make_lobby_cycler(lobby_config_box, "Options / level-up", str(CHOICES_OPTS[cfg_choices_i]), func():
			cfg_choices_i = (cfg_choices_i + 1) % CHOICES_OPTS.size()
			_apply_menu_config()
			net.send_config(cfg_choices, cfg_xp_rate, cfg_enemy_scale)
			_refresh_lobby_config_display())
		_make_lobby_cycler(lobby_config_box, "XP rate", str(XP_OPTS[cfg_xp_i]) + "x", func():
			cfg_xp_i = (cfg_xp_i + 1) % XP_OPTS.size()
			_apply_menu_config()
			net.send_config(cfg_choices, cfg_xp_rate, cfg_enemy_scale)
			_refresh_lobby_config_display())
		_make_lobby_cycler(lobby_config_box, "Enemy scale", str(SCALE_OPTS[cfg_scale_i]) + "x", func():
			cfg_scale_i = (cfg_scale_i + 1) % SCALE_OPTS.size()
			_apply_menu_config()
			net.send_config(cfg_choices, cfg_xp_rate, cfg_enemy_scale)
			_refresh_lobby_config_display())
	else:
		_make_config_label(lobby_config_box, "Options / level-up", str(cfg_choices))
		_make_config_label(lobby_config_box, "XP rate", str(cfg_xp_rate) + "x")
		_make_config_label(lobby_config_box, "Enemy scale", str(cfg_enemy_scale) + "x")


func _make_lobby_cycler(parent: Node, label: String, text: String, on_press: Callable) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var l := Label.new()
	l.text = label
	l.add_theme_font_size_override("font_size", 18)
	l.custom_minimum_size = Vector2(220, 38)
	row.add_child(l)
	var b := Button.new()
	b.custom_minimum_size = Vector2(132, 38)
	b.add_theme_font_size_override("font_size", 18)
	b.text = text
	b.pressed.connect(on_press)
	row.add_child(b)


func _make_config_label(parent: Node, label: String, value: String) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var l := Label.new()
	l.text = label
	l.add_theme_font_size_override("font_size", 18)
	l.custom_minimum_size = Vector2(220, 38)
	row.add_child(l)
	var v := Label.new()
	v.text = value
	v.add_theme_font_size_override("font_size", 18)
	v.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	row.add_child(v)


func start_game(ids: Array) -> void:
	ids.sort()
	peer_ids = ids
	local_id = multiplayer.get_unique_id()
	# Set before _build_world(): the host's starter-weapon pick (_grant_starters ->
	# _trigger_picks -> open_picks) fires synchronously from within it, and open_picks
	# is a no-op while not playing.
	playing = true
	_reset_run_state()
	_build_world()
	menu_panel.visible = false
	lobby_panel.visible = false
	hud_root.visible = true
	if hint_label != null:
		hint_label.text = HINT_SOLO if is_solo() else HINT_COOP
	sim.apply_fast_forward()
	if net.active and not is_host():
		# Save now (not just on disconnect) so a client whose game crashes/closes
		# outright -- with no chance to run a disconnect handler -- can still
		# rejoin after relaunching.
		_save_rejoin_state(local_id, ip_edit.text.strip_edges(), lobby_port)
	if OS.get_environment("NICESWARM_NET") != "":
		print("[test] start_game peers=%s local=%d host=%s" % [str(peer_ids), local_id, str(is_host())])


func reset_game() -> void:
	if not playing:
		return  # a not-yet-rejoined client on the menu shouldn't see the host's run events
	get_tree().paused = false
	_clear_world()
	_reset_run_state()
	_build_world()
	playing = true


func _reset_run_state() -> void:
	_score = {}
	net_scores = []
	elapsed = 0.0
	kills = 0
	level = 1
	xp = 0
	net_xp_needed = 6
	game_over = false
	leveling = false
	free_choice = false
	pending_chests = 0
	picks_starter = false
	picked_ids = {}
	choice_history = {}
	i_chose = false
	paused_menu = false
	menu_open_pids = {}
	_force_close_ingame_menu()
	spawner.reset()
	item_seq = 0
	enemies_by_id = {}
	gems_by_id = {}
	pickups_by_id = {}
	telegraphs_by_id = {}
	state_buffers = {}
	last_tick = {0: -1, 1: -1, 2: -1, 3: -1}
	tick_counter = 0
	level_panel.visible = false
	end_panel.visible = false
	pause_panel.visible = false


func _clear_world() -> void:
	get_tree().paused = false
	players = {}
	if world != null and is_instance_valid(world):
		world.queue_free()
	world = null


func _build_world(grant_starters: bool = true) -> void:
	world = Node2D.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)

	var bg := Background.new()
	bg.arena = ARENA
	world.add_child(bg)

	for i in peer_ids.size():
		var pid: int = peer_ids[i]
		var info: Dictionary = lobby_players.get(pid, {})
		var pos := Vector2.from_angle(TAU * i / maxi(peer_ids.size(), 1)) * 60.0
		_register_player(_make_player_node(pid, info, pos, i))
	if grant_starters:
		_grant_starters()


## Builds (but does not register) a Player node from lobby appearance info.
## `fallback_color_idx` is used when the roster has no saved color for this
## peer yet (e.g. spawn-order index in _build_world).
func _make_player_node(pid: int, info: Dictionary, pos: Vector2, fallback_color_idx: int = 0) -> Player:
	var p := Player.new()
	p.name = "Player_%d" % pid
	p.peer_id = pid
	p.color_idx = int(info.get("color", fallback_color_idx)) % Player.COLORS.size()
	p.shape_idx = int(info.get("shape", 0)) % Player.SHAPES.size()
	p.player_name = String(info.get("name", "Player"))
	p.is_local = pid == local_id
	p.arena = ARENA
	p.position = pos
	return p


## Wires a freshly built Player node into the world/bookkeeping shared by every
## entry path (initial build, mid-game late join, ally late-join notification).
func _register_player(p: Player) -> void:
	p.health_changed.connect(_on_player_hp_changed.bind(p))
	p.died.connect(_on_player_downed.bind(p))
	world.add_child(p)
	players[p.peer_id] = p
	_score[p.peer_id] = {"damage": 0.0, "xp": 0, "revives": 0, "deaths": 0}


## Decides how each player gets their first weapon. Headless/test runs get a
## fixed loadout (no input available); interactive play opens a "pick 1 of 3
## starting weapons" choice (host-triggered, broadcast like any level-up).
func _grant_starters() -> void:
	var test := OS.get_environment("NICESWARM_TEST")
	var headless := test != "" or OS.get_environment("NICESWARM_NET") != "" or OS.get_environment("NICESWARM_SIM") != ""
	if not headless:
		if is_host():
			_trigger_picks(true, true)  # free + starter
		return
	for pid in players:
		var p: Player = players[pid]
		p.add_weapon("bolt")
		match test:
			"all_weapons", "score":
				for wid in WEAPON_INFO:
					if p.get_weapon(wid) == null:
						p.add_weapon(wid)
			"merge":
				p.add_weapon("nova")
				p.get_weapon("bolt").level = MAX_WEAPON_LEVEL
				p.get_weapon("nova").level = MAX_WEAPON_LEVEL
				apply_choice(pid, "merge_bolt|nova")
				print("[test] merged -> %s (id %s), weapons=%d" \
					% [p.weapons[0].display_name, p.weapons[0].weapon_id, p.weapons.size()])
				# regression guard: build the pick pool with a level-1 signature fusion
				print("[test] pool ok, options=%d" % _build_choice_pool(p).size())
			"deep":
				# Synthetic worst case for the late-game regression: every count-scaling
				# weapon forced far past the Lv3 pool cap — exactly what unbounded fusion
				# leveling enables. The FF census then shows per-level node-count growth,
				# and FF auto-merge deepens it into real fusions over the run.
				for wid in ["frost", "missiles", "lightning", "mines"]:
					p.add_weapon(wid)
				for wid in ["bolt", "frost", "missiles", "lightning", "mines"]:
					var w := p.get_weapon(wid)
					if w != null:
						w.level = 10
				print("[test] deep build: 5 count-weapons forced to L10")
			"all_fusions":
				for pair in [["bolt", "nova"], ["frost", "lightning"], ["flame", "venom"],
						["gravity", "nova"], ["mines", "missiles"], ["laser", "orbit"],
						["frost", "glaive"], ["bolt", "lightning"], ["flame", "nova"],
						["frost", "orbit"], ["frost", "gravity"], ["glaive", "lightning"],
						["flame", "mines"], ["missiles", "nova"], ["gravity", "venom"],
						["orbit", "venom"], ["nova", "orbit"], ["bolt", "frost"], ["lightning", "venom"], ["lightning", "orbit"], ["flame", "lightning"], ["glaive", "nova"],
						["missiles", "turret"], ["laser", "turret"], ["frost", "turret"],
						["laser", "nova"], ["bolt", "missiles"], ["nova", "venom"],
						["bolt", "turret"], ["orbit", "turret"], ["nova", "turret"],
						["glaive", "turret"], ["lightning", "turret"], ["flame", "turret"],
						["mines", "turret"], ["gravity", "turret"], ["turret", "venom"],
						["frost", "nova"], ["flame", "frost"], ["gravity", "orbit"],
						["glaive", "gravity"], ["lightning", "nova"], ["mines", "orbit"],
						["flame", "gravity"], ["gravity", "laser"], ["gravity", "lightning"],
						["gravity", "mines"], ["gravity", "missiles"],
						["glaive", "mines"], ["laser", "mines"], ["lightning", "mines"],
						["mines", "nova"], ["mines", "venom"],
						["flame", "glaive"], ["flame", "laser"], ["flame", "missiles"], ["flame", "orbit"],
						["glaive", "laser"], ["glaive", "missiles"], ["glaive", "orbit"], ["glaive", "venom"],
						["laser", "lightning"], ["laser", "missiles"], ["laser", "venom"],
						["lightning", "missiles"], ["missiles", "orbit"], ["missiles", "venom"]]:
					var fw := Fusions.make(pair[0], pair[1])
					fw.level = MAX_WEAPON_LEVEL
					p.add_child(fw)
					p.weapons.append(fw)
				print("[test] fusion weapons active: %d" % (p.weapons.size() - 1))
	if test == "bomber" and is_host():
		for ti in 3:  # one of every caster tier: Bomber, Diviner, Oracle
			spawner.spawn_enemy("caster", ti)
			spawner.spawn_enemy("caster", ti)
		print("[test] caster tiers spawned")
	if test == "heat":  # verify dynamic difficulty responds to clear rate
		for s in [[1.0, 1.0], [3.0, 1.0], [5.0, 1.0], [2.0, 2.0], [6.0, 2.0]]:
			spawner.clear_ema = s[0]
			spawner.spawn_rate = s[1]
			print("[test] heat clear=%.0f/s spawn=%.0f/s -> %.2f" \
				% [spawner.clear_ema, spawner.spawn_rate, clampf((spawner.clear_ema - spawner.spawn_rate) / (spawner.spawn_rate * 2.0 + 1.0), 0.0, 1.0)])
		spawner.clear_ema = 0.0
		spawner.spawn_rate = 1.0
	if test == "zoo" and is_host():  # spawn one of every class/tier
		for ty in spawner.types:
			spawner.spawn_enemy(ty.cls, ty.tier)
		print("[test] zoo spawned: %d types" % spawner.types.size())


# --- frame loops -------------------------------------------------------------

func _process(delta: float) -> void:
	if not playing:
		return
	if countdown_time > 0.0:  # resume countdown holds the world until it reaches zero
		_tick_countdown(delta)
		return
	var running := not (game_over or leveling or get_tree().paused)
	if running:
		elapsed += delta  # clients advance too; host HUD sync corrects drift
	if is_host() and running:
		if elapsed >= WIN_TIME:
			_end_game(true)
			return
		if OS.get_environment("NICESWARM_TEST") == "score" and elapsed > 4.0 and not game_over:
			_end_game(true)  # headless scoreboard check
			return
		spawner.update_difficulty(delta)
		spawner.run_spawning(delta)
		_run_revives(delta)
		if Engine.time_scale > 1.0:  # NICESWARM_FF: log progress at each game-minute
			sim.ff_minute_log()
	# Headless: auto-resolve level-up picks (sim-aware; else the first level-up pauses forever).
	if leveling and (sim.active or Engine.time_scale > 1.0):
		if sim.active:
			sim.autopick()
		elif not i_chose and not current_choices.is_empty():
			_choose_upgrade(0)
	hud.update()


func _physics_process(delta: float) -> void:
	if not playing:
		return
	# Rebuild the shared enemy index first, every tick, in EVERY mode (solo returns
	# below at the net.active guard, but weapons/projectiles still query the grid).
	# Main is the scene root, so this runs before any weapon/enemy _physics_process.
	_rebuild_enemy_grid()
	if not net.active:
		return
	t_player += delta
	if t_player >= 0.05:
		t_player = 0.0
		var lp: Player = players.get(local_id)
		if lp != null:
			net.send_player_state(local_id, lp.global_position, lp.facing,
				lp.dash_active > 0.0)
	if not is_host():
		return
	t_enemy += delta
	if t_enemy >= 1.0 / 12.0:
		t_enemy = 0.0
		_send_state(STATE_ENEMIES)
	t_items += delta
	if t_items >= 1.0 / 8.0:
		t_items = 0.0
		_send_state(STATE_GEMS)
		_send_state(STATE_PICKUPS)
		_send_state(STATE_TELEGRAPHS)
	t_hud += delta
	if t_hud >= 0.25:
		t_hud = 0.0
		net.send_hud_state(elapsed, xp, _xp_needed(), level, kills, spawner.heat_cur, spawner.difficulty)


# --- shared enemy spatial index ----------------------------------------------

func _rebuild_enemy_grid() -> void:
	_enemy_list = get_tree().get_nodes_in_group("enemies")
	_enemy_grid.clear()
	for e in _enemy_list:
		var c := _cell(e.global_position)
		var bucket: Array = _enemy_grid.get(c, [])
		if bucket.is_empty():
			_enemy_grid[c] = bucket
		bucket.append(e)


func _cell(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / GRID_CELL)), int(floor(p.y / GRID_CELL)))


## All live enemies, snapshotted once this tick — no per-call allocation or group scan.
func all_enemies() -> Array[Node]:
	return _enemy_list


## Enemies whose center is within `r` of `pos`. Broad-phase: callers keep their own
## precise `distance <= reach + e.radius` check, so pass `reach + a small margin`.
func enemies_in_radius(pos: Vector2, r: float) -> Array[Node]:
	var out: Array[Node] = []
	var rr := r * r
	var cmin := _cell(pos - Vector2(r, r))
	var cmax := _cell(pos + Vector2(r, r))
	for cx in range(cmin.x, cmax.x + 1):
		for cy in range(cmin.y, cmax.y + 1):
			var bucket: Array = _enemy_grid.get(Vector2i(cx, cy), [])
			for e in bucket:
				if pos.distance_squared_to(e.global_position) <= rr:
					out.append(e)
	return out


## Nearest enemy to `pos` within `max_range`, via the grid (replaces full-group scans).
func nearest_enemy_to(pos: Vector2, max_range: float) -> Node2D:
	var best: Node2D = null
	var best_d := max_range * max_range
	var cmin := _cell(pos - Vector2(max_range, max_range))
	var cmax := _cell(pos + Vector2(max_range, max_range))
	for cx in range(cmin.x, cmax.x + 1):
		for cy in range(cmin.y, cmax.y + 1):
			var bucket: Array = _enemy_grid.get(Vector2i(cx, cy), [])
			for e in bucket:
				var d: float = pos.distance_squared_to(e.global_position)
				if d < best_d:
					best_d = d
					best = e
	return best


# --- host: spawning ----------------------------------------------------------

## Host only: a bombardier marks a danger zone; it detonates after `warn`
## (default TELEGRAPH_WARN) and hits any player still inside. Synced to clients
## via STATE_TELEGRAPHS so the reacting player sees the warning and can dash out.
## `ignore_cap`: bypass MAX_TELEGRAPHS — for boss slams, which must always render
## in full (a multi-strike pattern split by the cap would leave silent gaps).
func cast_telegraph(pos: Vector2, radius: float, damage: int, effect: int = 0, warn: float = -1.0, ignore_cap: bool = false) -> void:
	if not ignore_cap and telegraphs_by_id.size() >= GameConfig.MAX_TELEGRAPHS:
		return  # arena already saturated with danger zones — don't blanket it (undodgeable)
	var tz := TelegraphZone.new()
	tz.radius = radius
	tz.warn = TELEGRAPH_WARN if warn < 0.0 else warn
	tz.damage = damage
	tz.effect = effect
	tz.main_ref = self
	tz.net_id = item_seq
	item_seq += 1
	tz.position = pos
	telegraphs_by_id[tz.net_id] = tz
	world.add_child(tz)
	Sfx.play("telegraph", pos)


## Host only: an Interceptor (T1-3) casts a lingering jamming field that
## destroys player projectiles once `warn` elapses, for `life` seconds after.
## Synced to clients via STATE_TELEGRAPHS (effect EFFECT_INTERCEPT) so puppets
## register the same field in EnemyGrid and destroy their own local projectile
## visuals too — see EnemyGrid.in_interceptor_zone.
func cast_intercept_zone(pos: Vector2, radius: float, life: float) -> void:
	var tz := TelegraphZone.new()
	tz.radius = radius
	tz.warn = TELEGRAPH_WARN
	tz.life = life
	tz.effect = TelegraphZone.EFFECT_INTERCEPT
	tz.main_ref = self
	tz.net_id = item_seq
	item_seq += 1
	tz.position = pos
	telegraphs_by_id[tz.net_id] = tz
	world.add_child(tz)
	Sfx.play("telegraph", pos)


# --- host: drops, pickups, revives -------------------------------------------

func _on_enemy_killed(enemy: Enemy) -> void:
	enemies_by_id.erase(enemy.net_id)
	if spawner.types[enemy.type_id].cls == "bouncer":
		spawner.bouncer_live -= 1
	if enemy.xp_value <= 0:  # shard bullets: no kill credit, no gem, no drop
		return
	kills += 1
	if sim.active:
		sim.age_sum += enemy.age
	spawner.add_kill()
	# bursters spit a ring of shard bullets on death (deferred — see EnemySpawner.spawn_burst)
	if enemy.burst_count > 0 and enemies_by_id.size() + enemy.burst_count <= ENEMY_CAP:
		spawner.spawn_burst.call_deferred(enemy.global_position, enemy.burst_count)
	# At the gem cap, don't spawn another ground gem (they're _process-d, drawn and synced
	# every frame). Funnel the XP into the gem farthest from any player instead.
	if gems_by_id.size() >= MAX_GEMS:
		_condense_gem(enemy.xp_value)
	else:
		var gem := XpGem.new()
		gem.value = enemy.xp_value
		gem.main_ref = self
		gem.net_id = item_seq
		item_seq += 1
		gem.position = enemy.global_position
		gem.collected.connect(_on_gem_collected.bind(gem))
		gems_by_id[gem.net_id] = gem
		world.add_child(gem)

	if enemy.elite:
		_spawn_pickup("chest", enemy.global_position + Vector2(20.0, 0.0))
	elif enemy.xp_value >= 5 and not enemy.caster:  # tanks (Brute/Behemoth)
		if randf() < 0.7:
			var kinds := ["heart", "bomb", "magnet"]
			_spawn_pickup(kinds.pick_random(), enemy.global_position + Vector2(20.0, 0.0))
	elif randf() < 0.015:
		_spawn_pickup("heart", enemy.global_position)


## At the gem cap, add `value` to the existing gem farthest from its nearest player (the
## one least likely to be collected soon). It auto-renders red/large once its value crosses
## GEM_CONDENSED_THRESHOLD; clients pick the new value up from the gem sync.
func _condense_gem(value: int) -> void:
	var best: XpGem = null
	var best_d := -1.0
	for id in gems_by_id:
		var g = gems_by_id[id]
		if not is_instance_valid(g):
			continue
		var p: Node2D = nearest_alive_player(g.global_position)
		var d: float = 0.0 if p == null else g.global_position.distance_squared_to(p.global_position)
		if d > best_d:
			best_d = d
			best = g
	if best != null:
		best.value += value
		best.queue_redraw()


func _spawn_pickup(kind: String, pos: Vector2) -> void:
	var p := Pickup.new()
	p.kind = kind
	p.main_ref = self
	p.net_id = item_seq
	item_seq += 1
	p.position = pos
	p.taken.connect(_on_pickup_taken.bind(p))
	pickups_by_id[p.net_id] = p
	world.add_child(p)


func _on_pickup_taken(kind: String, by: Node2D, pickup: Pickup) -> void:
	pickups_by_id.erase(pickup.net_id)
	match kind:
		"heart":
			by.heal(2)
			Sfx.play("gem", by.global_position)
		"bomb":
			_bomb_fx(by.global_position)
			net.send_event(EVENT_BOMB, by.global_position)
			for e in Main.instance.all_enemies():
				if is_instance_valid(e) and by.global_position.distance_to(e.global_position) <= 850.0:
					e.take_hit(30.0, by.global_position)
		"magnet":
			Sfx.play("gem", by.global_position)
			for id in gems_by_id.keys():
				var g = gems_by_id[id]
				if is_instance_valid(g):
					g.force_pull = true
				else:
					gems_by_id.erase(id)
		"chest":
			Sfx.play("chest", by.global_position)
			pending_chests += 1
			_maybe_open_picks()


func _bomb_fx(pos: Vector2) -> void:
	var fx := RingFx.new()
	fx.position = pos
	fx.radius = 60.0
	fx.max_radius = 700.0
	fx.life = 0.5
	fx.color = Color(1.0, 0.7, 0.3)
	world.add_child(fx)
	Sfx.play("bomb", pos)
	var lp: Player = players.get(local_id)
	if lp != null:
		lp.shake = 14.0


func _run_revives(delta: float) -> void:
	for p in players.values():
		if not p.downed:
			continue
		var helper: Player = null
		for q in players.values():
			if q != p and not q.downed \
					and q.global_position.distance_to(p.global_position) <= 70.0:
				helper = q
				break
		if helper != null:
			p.revive_progress += delta / 3.0
		else:
			# decay very slowly — progress is mostly kept if the helper steps away
			# briefly, so an ally doesn't have to hover the whole time
			p.revive_progress = maxf(p.revive_progress - delta * 0.07, 0.0)
		if p.revive_progress >= 1.0:
			if helper != null and _score.has(helper.peer_id):
				_score[helper.peer_id].revives += 1  # credit the reviver
			p.revive()  # emits health_changed -> broadcast
		else:
			net.send_revive(p.peer_id, p.revive_progress)


# --- XP, party level & picks ---------------------------------------------------

func _on_gem_collected(value: int, gem: XpGem) -> void:
	gems_by_id.erase(gem.net_id)
	xp += value
	var who: Node2D = nearest_alive_player(gem.global_position)  # the gem flew to them
	if who != null and _score.has(who.peer_id):
		_score[who.peer_id].xp += value
	Sfx.play("gem", null, -8.0)
	_maybe_open_picks()


## Cost at the current level to reach the next (three-band curve in GameConfig).
func _xp_needed() -> int:
	# Effective XP rate = menu cfg_xp_rate * GameConfig.XP_GAIN_MULT (base 0.5 = half leveling speed).
	return GameConfig.xp_for_level(level, cfg_xp_rate * GameConfig.XP_GAIN_MULT)


func _current_needed() -> int:
	return _xp_needed() if is_host() else net_xp_needed


func _maybe_open_picks() -> void:
	if leveling or game_over or not is_host():
		return
	if pending_chests > 0:
		pending_chests -= 1
		_trigger_picks(true)
	elif xp >= _xp_needed():
		xp -= _xp_needed()
		level += 1
		spawner.add_level_difficulty()  # leveling up directly raises difficulty
		_trigger_picks(false)


func _trigger_picks(free: bool, starter: bool = false) -> void:
	picked_ids = {}
	net.send_open_picks(free, starter)
	open_picks(free, starter)


func open_picks(free: bool, starter: bool = false) -> void:
	if not playing:
		return  # a not-yet-rejoined client on the menu shouldn't see the host's run events
	if ingame_menu:
		_force_close_ingame_menu()  # a level-up pre-empts an open menu (clears safe/freeze)
	_cancel_countdown()  # a (chained) pick supersedes any in-flight resume countdown
	leveling = true
	free_choice = free
	picks_starter = starter
	i_chose = false
	get_tree().paused = true
	Sfx.play("levelup" if starter else ("chest" if free else "levelup"))
	if starter:
		panel_title.text = "CHOOSE YOUR STARTING WEAPON"
	elif free:
		panel_title.text = "TREASURE — everyone picks a reward"
	else:
		panel_title.text = "LEVEL UP — everyone picks an upgrade"
	_roll_choices()
	level_panel.visible = true


func _build_choice_pool(p: Player) -> Array:
	var pool := []
	# Starter pick: just three random weapons to begin the run.
	if picks_starter:
		for wid in WEAPON_INFO:
			var sinfo: Dictionary = WEAPON_INFO[wid]
			pool.append({"id": "learn_" + wid, "cat": "starter",
				"name": "%s" % sinfo.name, "desc": sinfo.learn})
		return pool
	# [NEW] — weapons not currently in a slot (a fused-away base can be relearned fresh)
	if p.weapons.size() < MAX_WEAPONS:
		for wid in WEAPON_INFO:
			if p.get_weapon(wid) == null:
				var info: Dictionary = WEAPON_INFO[wid]
				pool.append({"id": "learn_" + wid, "cat": "new",
					"name": "[NEW]  %s" % info.name, "desc": info.learn})
	# [Lv n] — level-ups for owned weapons (base, signature fusion, or amalgam)
	for w in p.weapons:
		if w.level < MAX_WEAPON_LEVEL:
			var desc: String
			if w is WeaponFused:
				desc = "+1 level to every fused part"
			elif WEAPON_INFO.has(w.weapon_id):
				desc = WEAPON_INFO[w.weapon_id].level
			else:
				desc = "+1 level — strengthen this fusion"  # signature fusion weapon
			pool.append({"id": "lv_" + w.weapon_id, "cat": "level",
				"name": "[Lv %d]  %s" % [w.level + 1, w.display_name], "desc": desc})
	# Merges of any two maxed attacks. A signature pair -> [FUSE] a distinct new
	# weapon; anything else -> [AMALGAM] both running together in one slot.
	var maxed := []
	for w in p.weapons:
		if w.level >= MAX_WEAPON_LEVEL:
			maxed.append(w)
	var merges := []
	for i in maxed.size():
		for j in range(i + 1, maxed.size()):
			# Fusion depth cap: a final-tier fusion (T2) can't be merged further.
			if not Fusions.can_merge(maxed[i].tier, maxed[j].tier):
				continue
			var sig: Dictionary = Fusions.info(maxed[i].weapon_id, maxed[j].weapon_id)
			var entry := {"id": "merge_%s|%s" % [maxed[i].weapon_id, maxed[j].weapon_id]}
			if not sig.is_empty():
				entry["cat"] = "fuse"
				entry["name"] = "[FUSE]  %s" % sig.name
				entry["desc"] = "NEW WEAPON — %s" % sig.desc
			else:
				entry["cat"] = "amalgam"
				entry["name"] = "[AMALGAM]  %s + %s" % [maxed[i].display_name, maxed[j].display_name]
				entry["desc"] = "both run together in one slot, leveled as one"
			merges.append(entry)
	merges.shuffle()
	pool.append_array(merges.slice(0, 2))
	# [STAT] — generalized axes that touch every weapon's math
	pool.append({"id": "st_power", "cat": "stat", "name": "[STAT]  Power", "desc": "+25% damage — every weapon"})
	if p.rate_mult > 0.5:
		pool.append({"id": "st_rate", "cat": "stat", "name": "[STAT]  Haste", "desc": "+14% attack speed — every weapon"})
	if p.area_mult < 2.5:
		pool.append({"id": "st_area", "cat": "stat", "name": "[STAT]  Area", "desc": "+20% size & reach — AoE, beams, blasts"})
	if p.duration_mult < 2.5:
		pool.append({"id": "st_duration", "cat": "stat", "name": "[STAT]  Duration", "desc": "+25% effect time — turrets, trails, projectiles"})
	if p.move_speed < 400.0:
		pool.append({"id": "st_speed", "cat": "stat", "name": "[STAT]  Swift Boots", "desc": "+12% move speed"})
	pool.append({"id": "st_hp", "cat": "stat", "name": "[STAT]  Vitality", "desc": "+1 max HP and heal 2"})
	if p.pickup_range < 360.0:
		pool.append({"id": "st_magnet", "cat": "stat", "name": "[STAT]  Magnet", "desc": "+50% pickup range"})
	if p.dash_cooldown > 1.2:
		pool.append({"id": "st_dash", "cat": "stat", "name": "[STAT]  Slipstream", "desc": "-20% dash cooldown"})
	return pool


func _roll_choices() -> void:
	var me: Player = players.get(local_id)
	if me == null:
		return
	var pool := _build_choice_pool(me)
	# Guarantee up to two build-advancing options each roll, both protected from
	# the random shuffle: (1) a fusion/merge when one is available (the build
	# payoff), and (2) a level-up of an owned weapon/fusion, so you can always
	# strengthen what you already run. Remaining slots fill randomly from the rest.
	var merges := pool.filter(func(e): return e.get("cat", "") in ["fuse", "amalgam"])
	var levels := pool.filter(func(e): return e.get("cat", "") == "level")
	var rest := pool.filter(func(e): return not (e.get("cat", "") in ["fuse", "amalgam", "level"]))
	merges.shuffle()
	levels.shuffle()
	var chosen := []
	if not merges.is_empty():
		chosen.append(merges.pop_back())
	if not levels.is_empty():
		chosen.append(levels.pop_back())  # always offer an owned-weapon/fusion level-up
	var filler: Array = levels + rest  # leftover level-ups stay eligible too
	filler.shuffle()
	for e in filler:
		if chosen.size() >= cfg_choices:
			break
		chosen.append(e)
	chosen.shuffle()
	current_choices = chosen.slice(0, cfg_choices)
	for i in choice_buttons.size():
		if i < current_choices.size():
			var u: Dictionary = current_choices[i]
			choice_buttons[i].text = "%d.  %s" % [i + 1, u.name]
			var col: Color = CAT_COLORS.get(u.get("cat", "stat"), Color.WHITE)
			choice_buttons[i].add_theme_color_override("font_color", col)
			choice_buttons[i].add_theme_color_override("font_color_hover", col.lightened(0.2))
			choice_buttons[i].add_theme_color_override("font_color_pressed", col)
			choice_buttons[i].visible = true
		else:
			choice_buttons[i].visible = false


func _choose_upgrade(index: int) -> void:
	if not leveling or i_chose or index >= current_choices.size():
		return
	i_chose = true
	Sfx.play("click")
	for b in choice_buttons:
		b.visible = false
	if peer_ids.size() > 1:
		panel_title.text = "Waiting for your allies to pick..."
	net.submit_choice(local_id, current_choices[index].id)


## `replay`: true when reconstructing a rejoining client's history -- applies the
## same state changes silently (no SFX, no "wait for all" bookkeeping).
func apply_choice(pid: int, id: String, replay: bool = false) -> void:
	var p: Player = players.get(pid)
	if p == null:
		return
	if not replay:
		if not choice_history.has(pid):
			choice_history[pid] = []
		choice_history[pid].append(id)
	if id.begins_with("learn_"):
		p.add_weapon(id.trim_prefix("learn_"))
	elif id.begins_with("merge_"):
		var pair := id.trim_prefix("merge_").split("|")
		if pair.size() == 2:
			p.merge_weapons(pair[0], pair[1])
			if not replay:
				Sfx.play("merge")
	elif id.begins_with("lv_"):
		var w := p.get_weapon(id.trim_prefix("lv_"))
		if w is WeaponFused:
			w.level_up()
		elif w != null:
			w.level += 1
	else:
		match id:
			"st_power":
				p.power_stat *= 1.25  # damage_mult is derived from power_stat * party-level scaling
			"st_rate":
				p.rate_mult *= 0.88
			"st_area":
				p.area_mult *= 1.2
			"st_duration":
				p.duration_mult *= 1.25
			"st_speed":
				p.move_speed *= 1.12
			"st_hp":
				p.gain_vitality()
			"st_magnet":
				p.pickup_range *= 1.5
			"st_dash":
				p.dash_cooldown = maxf(p.dash_cooldown * 0.8, 1.2)
		# Track stat picks for the on-screen icons (runs on every peer via call_local).
		p.stat_levels[id] = int(p.stat_levels.get(id, 0)) + 1
	if is_host() and not replay:
		picked_ids[pid] = true
		_check_all_picked()


func _check_all_picked() -> void:
	if not leveling:
		return
	for pid in peer_ids:
		if not picked_ids.has(pid):
			var p: Player = players.get(pid)
			if p != null and p.disconnected:
				continue  # ghosted: don't block the round waiting for an absent player
			return
	net.send_resume()
	resume_after_picks()


func resume_after_picks() -> void:
	leveling = false
	picks_starter = false
	level_panel.visible = false
	# Host with banked levels/chests: chain straight into the next pick — no countdown mid-chain.
	if is_host() and (pending_chests > 0 or xp >= _xp_needed()):
		get_tree().paused = false
		_maybe_open_picks()
		return
	# Final return to gameplay — count it in (cosmetic; the world stays paused until it ends).
	_begin_resume_countdown(func() -> void: get_tree().paused = false)


# --- HP / downed / end ---------------------------------------------------------

func _on_player_hp_changed(_hp: int, _max_hp: int, p: Player) -> void:
	if is_host():
		net.send_player_hp(p.peer_id, p.hp, p.max_hp, p.downed)


func _on_player_downed(p: Player) -> void:
	if is_host():
		if _score.has(p.peer_id):
			_score[p.peer_id].deaths += 1
		_check_all_downed()


## Host: credit damage a player's weapon dealt (called from enemy.take_hit).
func add_damage(pid: int, amount: float) -> void:
	if _score.has(pid):
		_score[pid].damage += amount
	spawner.add_damage_sample(amount)  # feed the rolling party-DPS window (boss hp sizing)


func _check_all_downed() -> void:
	if players.is_empty():
		return
	for p in players.values():
		if not p.downed:
			return
	_end_game(false)


func _end_game(won: bool) -> void:
	if game_over:
		return
	# scoreboard rows: [color_idx, damage, xp, revives, deaths] per player, by damage
	var rows := []
	for pid in peer_ids:
		var sc: Dictionary = _score.get(pid, {"damage": 0.0, "xp": 0, "revives": 0, "deaths": 0})
		var ci: int = players[pid].color_idx if players.has(pid) else 0
		rows.append([ci, sc.damage, sc.xp, sc.revives, sc.deaths])
	rows.sort_custom(func(a, b): return a[1] > b[1])
	var packed := PackedFloat32Array()
	for r in rows:
		packed.append_array(PackedFloat32Array([r[0], r[1], r[2], r[3], r[4]]))
	if OS.get_environment("NICESWARM_TEST") == "score":
		print("[test] scoreboard rows=%d damage(P1)=%d kills=%d" % [rows.size(), int(round(rows[0][1])) if not rows.is_empty() else 0, kills])
	net.send_end(won, elapsed, level, kills, packed)
	apply_end(won, elapsed, level, kills, packed)


func apply_end(won: bool, elapsed_: float, level_: int, kills_: int, scores: PackedFloat32Array) -> void:
	if not playing or game_over:
		return
	game_over = true
	_force_close_ingame_menu()  # never end a run with a player stuck frozen/invulnerable
	if sim.report_end(won, elapsed_, level_, kills_):
		return  # a sim run printed its [sim] line and quit the process
	get_tree().paused = true
	end_title.text = "YOU SURVIVED THE NIGHT" if won \
		else ("YOU HAVE FALLEN" if is_solo() else "THE PARTY HAS FALLEN")
	end_title.add_theme_color_override("font_color",
		Color(0.5, 1.0, 0.6) if won else Color(1.0, 0.35, 0.35))
	var t := int(elapsed_)
	end_stats.text = "Survived %02d:%02d   •   Level %d   •   %d kills" \
		% [t / 60, t % 60, level_, kills_]
	_fill_scoreboard(scores)
	end_hint.text = "R play again   ·   M main menu" if is_host() else "Waiting for host…   ·   M main menu"
	end_panel.visible = true


## Build the end-screen scoreboard from packed [color_idx, dmg, xp, rev, deaths]×N rows.
func _fill_scoreboard(scores: PackedFloat32Array) -> void:
	for c in scoreboard_box.get_children():
		c.queue_free()
	for h in ["PLAYER", "DAMAGE", "XP", "REVIVES", "DEATHS"]:
		var header := Label.new()
		header.text = h
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if h == "PLAYER" else HORIZONTAL_ALIGNMENT_RIGHT
		header.add_theme_font_size_override("font_size", 18)
		header.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
		scoreboard_box.add_child(header)
	var i := 0
	while i + 4 < scores.size():
		var ci := int(scores[i])
		var col := Player.COLORS[ci % Player.COLORS.size()]
		var cells := ["P%d" % (ci + 1), str(int(round(scores[i + 1]))), str(int(scores[i + 2])),
			str(int(scores[i + 3])), str(int(scores[i + 4]))]
		for j in cells.size():
			var cell := Label.new()
			cell.text = cells[j]
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if j == 0 else HORIZONTAL_ALIGNMENT_RIGHT
			cell.add_theme_font_size_override("font_size", 20)
			cell.add_theme_color_override("font_color", col)
			scoreboard_box.add_child(cell)
		i += 5


func _restart() -> void:
	if not is_host():
		return
	net.send_reset()
	reset_game()


# --- network receivers (called by Net) -----------------------------------------

func apply_player_state(pid: int, pos: Vector2, facing: Vector2, dashing: bool) -> void:
	if not playing or pid == local_id:
		return
	var p: Player = players.get(pid)
	if p == null:
		return
	p.net_target = pos
	p.facing = facing
	p.remote_dashing = dashing


## Host -> everyone: a player's connection dropped (ghost them, invulnerable on
## host) or was restored (rejoin re-key already applied via apply_player_rejoined).
func apply_player_connection(pid: int, connected: bool) -> void:
	var p: Player = players.get(pid)
	if p == null:
		return
	p.disconnected = not connected
	p.safe = not connected


func apply_hud_state(elapsed_: float, xp_: int, needed: int, level_: int, kills_: int, heat: float, difficulty_: float) -> void:
	if is_host() or not playing:
		return
	elapsed = elapsed_
	xp = xp_
	net_xp_needed = needed
	level = level_
	kills = kills_
	spawner.net_heat = heat
	spawner.net_difficulty = difficulty_


func apply_player_hp(pid: int, hp_: int, max_: int, downed_: bool) -> void:
	var p: Player = players.get(pid)
	if p == null:
		return
	var old_hp: int = p.hp
	p.max_hp = max_
	p.hp = hp_
	if downed_ and not p.downed:
		p.downed = true
		p.revive_progress = 0.0
	elif not downed_ and p.downed:
		p.downed = false
		p.invuln = 2.0
		Sfx.play("revive", p.global_position)
	if hp_ < old_hp:
		Sfx.play("hurt", p.global_position)
	if pid == local_id and hp_ < old_hp:
		p.invuln = maxf(p.invuln, 0.9)
		p.shake = 10.0


func apply_revive(pid: int, ratio: float) -> void:
	var p: Player = players.get(pid)
	if p != null:
		p.revive_progress = ratio


func apply_pause(pause: bool) -> void:
	if not playing:
		return  # a not-yet-rejoined client on the menu shouldn't see the host's run events
	var was := paused_menu
	paused_menu = pause
	get_tree().paused = pause
	if pause:
		gameui._refresh_pause_roster()
		pause_panel.visible = not ingame_menu  # if MY menu is open, show that instead of the generic panel
	else:
		_cancel_countdown()  # authoritative unpause arrived — end any cosmetic countdown
		pause_panel.visible = false
		if was:
			Sfx.play("alert")  # the run resumed for everyone


func apply_event(type: int, pos: Vector2) -> void:
	if not playing:
		return  # a not-yet-rejoined client on the menu shouldn't see the host's run events
	match type:
		EVENT_BOMB:
			_bomb_fx(pos)


func apply_world_state(kind: int, tick: int, chunk: int, total: int,
		data: PackedFloat32Array) -> void:
	if is_host() or not playing:
		return
	if tick <= last_tick[kind]:
		return
	var kb: Dictionary = state_buffers.get_or_add(kind, {})
	var tb: Dictionary = kb.get_or_add(tick, {"total": total, "chunks": {}})
	tb.chunks[chunk] = data
	if tb.chunks.size() < total:
		return
	var merged := PackedFloat32Array()
	for c in total:
		merged.append_array(tb.chunks[c])
	kb.clear()
	if last_tick[kind] < 0 and OS.get_environment("NICESWARM_NET") != "":
		print("[test] first world state kind=%d entries=%d" % [kind, merged.size() / 4])
	last_tick[kind] = tick
	_apply_state(kind, merged)


func _apply_state(kind: int, data: PackedFloat32Array) -> void:
	var seen := {}
	var i := 0
	while i + 3 < data.size():
		var id := int(data[i])
		var pos := Vector2(data[i + 1], data[i + 2])
		var f := data[i + 3]
		i += 4
		seen[id] = true
		match kind:
			STATE_ENEMIES:
				var e = enemies_by_id.get(id)
				if e != null and not is_instance_valid(e):
					enemies_by_id.erase(id)
					e = null
				if e == null:
					if enemies_by_id.is_empty() and OS.get_environment("NICESWARM_NET") != "":
						print("[test] first enemy puppet id=%d at %s" % [id, str(pos)])
					e = spawner.make_enemy_by_type(int(f) % 1000)
					e.puppet = true
					e.net_id = id
					e.position = pos
					enemies_by_id[id] = e
					world.add_child(e)
				e.net_target = pos
				e.slow_timer = 0.5 if int(f) >= 1000 else 0.0
			STATE_GEMS:
				var g = gems_by_id.get(id)
				if g != null and not is_instance_valid(g):
					gems_by_id.erase(id)
					g = null
				if g == null:
					g = XpGem.new()
					g.puppet = true
					g.net_id = id
					g.value = int(f)
					g.position = pos
					gems_by_id[id] = g
					world.add_child(g)
				elif g.value != int(f):  # condensed on the host -> update value + recolor
					g.value = int(f)
					g.queue_redraw()
				g.net_target = pos
			STATE_PICKUPS:
				var pk = pickups_by_id.get(id)
				if pk != null and not is_instance_valid(pk):
					pickups_by_id.erase(id)
					pk = null
				if pk == null:
					pk = Pickup.new()
					pk.puppet = true
					pk.net_id = id
					pk.kind = PICKUP_KINDS[int(f)]
					pk.position = pos
					pickups_by_id[id] = pk
					world.add_child(pk)
				pk.net_target = pos
			STATE_TELEGRAPHS:
				var tz = telegraphs_by_id.get(id)
				if tz != null and not is_instance_valid(tz):
					telegraphs_by_id.erase(id)
					tz = null
				if tz == null:
					tz = TelegraphZone.new()
					tz.puppet = true
					tz.net_id = id
					tz.effect = int(f) / 10000     # effect packed as radius + effect*10000
					tz.radius = f - tz.effect * 10000.0
					tz.warn = TELEGRAPH_WARN
					tz.position = pos
					telegraphs_by_id[id] = tz
					world.add_child(tz)
	var dict := [enemies_by_id, gems_by_id, pickups_by_id, telegraphs_by_id][kind] as Dictionary
	for id in dict.keys():
		if seen.has(id):
			continue
		var node = dict[id]
		if is_instance_valid(node):
			match kind:
				STATE_ENEMIES:
					var pop := RingFx.new()
					pop.position = node.global_position
					pop.radius = node.radius * 0.5
					pop.max_radius = node.radius * 2.0
					pop.life = 0.25
					pop.color = node.color
					world.add_child(pop)
					Sfx.play("kill", node.global_position, -6.0)
				STATE_GEMS:
					Sfx.play("gem", null, -8.0)
				STATE_PICKUPS:
					Sfx.play("chest" if node.kind == "chest" else "gem", node.global_position)
				STATE_TELEGRAPHS:
					var pop := RingFx.new()
					pop.position = node.global_position
					pop.radius = node.radius * 0.6
					pop.max_radius = node.radius
					pop.life = 0.25
					pop.color = Color(0.3, 0.85, 0.95) if node.effect == TelegraphZone.EFFECT_INTERCEPT else Color(1.0, 0.3, 0.2)
					world.add_child(pop)
					Sfx.play("boom", node.global_position)
			node.queue_free()
		dict.erase(id)


func _send_state(kind: int) -> void:
	var data := PackedFloat32Array()
	# NOTE: assignments below stay untyped — assigning a freed instance to a
	# typed var raises before any is_instance_valid check could run
	match kind:
		STATE_ENEMIES:
			for id in enemies_by_id.keys():
				var e = enemies_by_id[id]
				if not is_instance_valid(e) or e.is_queued_for_deletion():
					enemies_by_id.erase(id)
					continue
				data.append_array(PackedFloat32Array([float(id),
					e.global_position.x, e.global_position.y,
					float(e.type_id) + (1000.0 if e.slow_timer > 0.0 else 0.0)]))
		STATE_GEMS:
			for id in gems_by_id.keys():
				var g = gems_by_id[id]
				if not is_instance_valid(g) or g.is_queued_for_deletion():
					gems_by_id.erase(id)
					continue
				data.append_array(PackedFloat32Array([float(id),
					g.global_position.x, g.global_position.y, float(g.value)]))
		STATE_PICKUPS:
			for id in pickups_by_id.keys():
				var pk = pickups_by_id[id]
				if not is_instance_valid(pk) or pk.is_queued_for_deletion():
					pickups_by_id.erase(id)
					continue
				data.append_array(PackedFloat32Array([float(id),
					pk.global_position.x, pk.global_position.y,
					float(PICKUP_KINDS.find(pk.kind))]))
		STATE_TELEGRAPHS:
			for id in telegraphs_by_id.keys():
				var tz = telegraphs_by_id[id]
				if not is_instance_valid(tz) or tz.is_queued_for_deletion():
					telegraphs_by_id.erase(id)
					continue
				data.append_array(PackedFloat32Array([float(id),
					tz.global_position.x, tz.global_position.y,
					tz.radius + tz.effect * 10000.0]))
	tick_counter += 1
	var per := 80 * 4  # 80 entries per chunk keeps packets under typical MTU
	var total := maxi(1, int(ceil(float(data.size()) / per)))
	for c in total:
		net.send_world_state(kind, tick_counter, c, total,
			data.slice(c * per, mini((c + 1) * per, data.size())))


# --- input ---------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not playing:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: int = event.keycode
	if key == KEY_F1:
		debug.toggle()
		return
	if countdown_time > 0.0:
		return  # swallow input while the resume countdown is running
	if game_over:
		if key == KEY_R:
			_restart()
		elif key == KEY_M:
			_to_menu()
	elif leveling:
		if key >= KEY_1 and key < KEY_1 + MAX_CHOICES:  # 1..6 select dynamically
			_choose_upgrade(key - KEY_1)
	elif ingame_menu:  # our own in-run menu/hub is open
		if key == KEY_ESCAPE:
			if codex_view != "":
				gameui._close_codex()        # ESC backs out of an open codex before resuming
			else:
				_resume_from_ingame_menu()
		elif key == KEY_C:
			gameui._show_codex("skills")
		elif key == KEY_V:
			gameui._show_codex("monsters")
		elif key == KEY_O:
			ingame_menu_hint.text = "Settings — coming soon"
		elif key == KEY_L and codex_view == "":
			_leave_from_menu()  # deliberate, hub-root only — never a stray key while reading a codex
	elif paused_menu:  # paused by another player's menu (or a reconnect): open my own menu, or leave with M
		if key == KEY_ESCAPE:
			_open_ingame_menu()  # open my own menu while the run is already paused
		elif key == KEY_M:
			_to_menu()
	elif key == KEY_ESCAPE:
		_open_ingame_menu()  # ESC opens the in-game menu — pauses the whole run for every player


## Leave the current run and return to the main menu. Disconnects from co-op
## (host leaving drops everyone; a client leaving just drops itself).
func _to_menu() -> void:
	# A client leaving mid-run (ESC menu "leave", or "M" while paused by the host) still
	# gets ghosted on the host -- the next "Join" can resume that character. A
	# finished run (game_over), solo play, or the host leaving has nothing to rejoin.
	var can_rejoin := net.active and not is_host() and not game_over
	net.leave()
	_clear_world()
	if can_rejoin:
		rejoin_old_id = local_id
		rejoin_pending = true
	else:
		_clear_rejoin_state()
	_show_menu("")


# --- in-run menu / hub ---------------------------------------------------------

## ESC during play. The hub is the same for everyone; only the freeze mechanic differs:
## the host (and solo) globally pause the run; a client can't pause the shared sim, so it
## holds its own avatar still and asks the host to make it invulnerable (auto-safe).
func _open_ingame_menu() -> void:
	if ingame_menu:
		return
	ingame_menu = true
	gameui._close_codex()  # always open on the hub root, never a stale codex view
	ingame_menu_panel.visible = true
	pause_panel.visible = false  # my own menu replaces any "PAUSED" panel I was shown
	# Opening any player's menu pauses the whole run for everyone (host-authoritative).
	if is_host():
		set_menu_open(local_id, true)
	else:
		net.send_request_pause(local_id, true)


## Close the hub. The run resumes (for everyone) only once NO player still has a menu open.
func _resume_from_ingame_menu() -> void:
	ingame_menu = false
	ingame_menu_panel.visible = false
	if is_host():
		set_menu_open(local_id, false)
	else:
		net.send_request_pause(local_id, false)
		pause_panel.visible = paused_menu  # still paused by another player's menu? keep the panel


## Host: track which players have a menu open and pause/resume the whole run accordingly.
## The run is paused for everyone while ANY player's menu is open; it resumes (with the
## alert cue) once the last one closes. Defers to the level-up / game-over flows, which own
## the pause in their own right.
func set_menu_open(pid: int, open: bool) -> void:
	if not is_host():
		return
	if open:
		menu_open_pids[pid] = true
	else:
		menu_open_pids.erase(pid)
	if leveling or game_over:
		return
	var want: bool = not menu_open_pids.is_empty()
	if want == paused_menu:
		return
	if want:
		apply_pause(true)
		net.send_set_paused(true)
	else:
		net.send_set_paused(false)
		apply_pause(false)


## Deliberate "leave game" from inside the hub (the L key) — the old accidental ESC path.
func _leave_from_menu() -> void:
	_to_menu()


## Drop all in-menu state immediately (no countdown) — used on leave / game over / reset so a
## menu-open player never gets stuck frozen or invulnerable.
func _force_close_ingame_menu() -> void:
	ingame_menu = false
	_cancel_countdown()
	gameui._close_codex()
	if ingame_menu_panel != null:
		ingame_menu_panel.visible = false
	_clear_local_safe()
	# drop our menu-pause contribution (the level-up / game-over / leave flows own the pause now)
	if is_host():
		menu_open_pids.erase(local_id)
	elif net.active:
		net.send_request_pause(local_id, false)


## Drop our local "menu safe" state and tell the host we're vulnerable + mobile again.
## Idempotent and the single teardown for safe/freeze, so any exit (resume, leave, game over,
## reset, a level-up pre-empting the menu) can call it without leaving a stuck flag.
func _clear_local_safe() -> void:
	var me: Player = players.get(local_id)
	if me != null:
		me.menu_frozen = false
		me.safe = false
	if net.active and not is_host():
		net.send_set_safe(local_id, false)


# --- resume countdown ----------------------------------------------------------

## Host: a client (pid) opened/closed its menu — toggle its host-side invulnerability.
func apply_set_safe(pid: int, safe: bool) -> void:
	# Host-only, and only the sender may mark itself safe (no spoofing other players).
	if not is_host() or not players.has(pid):
		return
	if pid != multiplayer.get_remote_sender_id():
		return
	players[pid].safe = safe


## Cosmetic-only countdown shown on a remote peer; the host drives the real unpause.
func begin_resume_countdown_remote() -> void:
	if not playing:
		return  # a not-yet-rejoined client on the menu shouldn't see the host's run events
	if DisplayServer.get_name() == "headless":
		return
	pause_panel.visible = false
	_begin_resume_countdown(Callable())


func _begin_resume_countdown(on_complete: Callable) -> void:
	# No resume countdown — resume immediately and just play an alert cue so everyone
	# knows the world is live again. (Headless/FF: silent + instant, keeps tests fast.)
	if not (DisplayServer.get_name() == "headless" or Engine.time_scale > 1.0):
		Sfx.play("alert")
	if on_complete.is_valid():
		on_complete.call()


func _tick_countdown(delta: float) -> void:
	var prev := countdown_time
	countdown_time -= delta
	# tick on each whole-second crossing (e.g. 2 -> 1)
	if int(ceil(prev)) != int(ceil(maxf(countdown_time, 0.0))) and countdown_time > 0.0:
		Sfx.play("clock")
	countdown_label.text = str(maxi(int(ceil(maxf(countdown_time, 0.0))), 1))
	if countdown_time <= 0.0:
		countdown_time = 0.0
		countdown_panel.visible = false
		var cb := _countdown_done
		_countdown_done = Callable()
		if cb.is_valid():
			cb.call()


func _cancel_countdown() -> void:
	countdown_time = 0.0
	_countdown_done = Callable()
	if countdown_panel != null:
		countdown_panel.visible = false


