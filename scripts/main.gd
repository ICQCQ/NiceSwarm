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

# Stat-upgrade ids (apply_choice) -> short label, for the debug panel's stat grid.
const STAT_INFO := {
	"st_power": "Power", "st_rate": "Haste", "st_area": "Area", "st_duration": "Duration",
	"st_speed": "Speed", "st_hp": "Vitality", "st_magnet": "Magnet", "st_dash": "Dash",
}

# --- session / network ---
var net: Net
var spawner: EnemySpawner
var playing := false
var peer_ids: Array = []        # all peer ids in the run, sorted
var players := {}               # peer_id -> Player
var _score := {}                # peer_id -> {damage, xp, revives, deaths} (host)
var net_scores: Array = []      # end-game scoreboard rows received by clients
var local_id := 1
var auto_start_on_join := false # test hook

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
var i_chose := false
var paused_menu := false
var _ff_min := -1               # NICESWARM_FF: last game-minute printed during a fast-forward run

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
var hp_label: Label
var timer_label: Label
var level_label: Label
var kills_label: Label
var dash_label: Label
var threat_label: Label
var allies_label: Label
var weapons_label: Label
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
var scoreboard_box: VBoxContainer
var pause_panel: Control
var pause_loadout: Label
var pause_roster: Label
var menu_panel: Control
var ip_edit: LineEdit
var port_edit: LineEdit
var status_label: Label
var start_btn: Button
var debug_panel: Control
var debug_god_btn: Button
var debug_fuse_a: OptionButton
var debug_fuse_b: OptionButton


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
	_build_ui()
	_show_menu("")
	match OS.get_environment("NICESWARM_NET"):  # headless test hooks
		"solo":
			_on_solo_pressed()
		"host":
			auto_start_on_join = true
			_on_host_pressed()
		"join":
			ip_edit.text = "127.0.0.1"
			_on_join_pressed()


func is_host() -> bool:
	return multiplayer.is_server()


func nearest_alive_player(pos: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for p in players.values():
		if p.downed:
			continue
		var d: float = pos.distance_squared_to(p.global_position)
		if d < best_d:
			best_d = d
			best = p
	return best


# --- menu / session flow ----------------------------------------------------

func _show_menu(message: String) -> void:
	playing = false
	menu_panel.visible = true
	hud_root.visible = false
	start_btn.visible = false
	status_label.text = message


func _apply_menu_config() -> void:
	cfg_choices = CHOICES_OPTS[cfg_choices_i]
	cfg_xp_rate = XP_OPTS[cfg_xp_i]
	cfg_enemy_scale = SCALE_OPTS[cfg_scale_i]


func _on_solo_pressed() -> void:
	net.leave()
	_apply_menu_config()
	start_game([1])


func _menu_port() -> int:
	var p := int(port_edit.text.strip_edges())
	if p < 1 or p > 65535:
		p = Net.PORT
		port_edit.text = str(Net.PORT)
	return p


func _on_host_pressed() -> void:
	var port := _menu_port()
	var err := net.host_game(port)
	if err != "":
		status_label.text = err
		return
	var ips := []
	for a in IP.get_local_addresses():
		if a.contains(".") and not a.begins_with("127."):
			ips.append(a)
	status_label.text = "Hosting on port %d\nYour LAN IP(s): %s\nPlayers: 1 (you)" \
		% [port, ", ".join(ips) if not ips.is_empty() else "?"]
	start_btn.visible = true


func _on_join_pressed() -> void:
	var port := _menu_port()
	var err := net.join_game(ip_edit.text.strip_edges(), port)
	status_label.text = err if err != "" \
		else "Connecting to %s:%d ..." % [ip_edit.text, port]


func _on_start_pressed() -> void:
	var ids: Array = [1]
	for p in multiplayer.get_peers():
		ids.append(p)
	net.lock_session()
	_apply_menu_config()
	net.send_config(cfg_choices, cfg_xp_rate, cfg_enemy_scale)
	net.send_start(PackedInt32Array(ids))
	start_game(ids)


func apply_config(choices: int, xp_rate: float, enemy_scale: float) -> void:
	cfg_choices = choices
	cfg_xp_rate = xp_rate
	cfg_enemy_scale = enemy_scale


func on_peer_connected(_id: int) -> void:
	if playing:
		return
	if is_host():
		status_label.text = status_label.text.rsplit("\n", true, 1)[0] \
			+ "\nPlayers: %d (you + %d)" % [1 + multiplayer.get_peers().size(),
				multiplayer.get_peers().size()]
		if auto_start_on_join:
			get_tree().create_timer(0.5).timeout.connect(_on_start_pressed)


func on_peer_disconnected(id: int) -> void:
	if not playing:
		if is_host():
			status_label.text += "\n(a player left)"
		return
	var p: Player = players.get(id)
	if p != null:
		p.queue_free()
	players.erase(id)
	peer_ids.erase(id)
	if is_host():
		picked_ids.erase(id)
		if leveling:
			_check_all_picked()
		_check_all_downed()


func on_join_ok() -> void:
	status_label.text = "Connected! Waiting for the host to start..."


func on_join_failed() -> void:
	net.leave()
	_show_menu("Could not connect. Check the IP and that the host is running.")


func on_server_disconnected() -> void:
	net.leave()
	_clear_world()
	_show_menu("Host disconnected.")


func start_game(ids: Array) -> void:
	ids.sort()
	peer_ids = ids
	local_id = multiplayer.get_unique_id()
	_reset_run_state()
	_build_world()
	playing = true
	menu_panel.visible = false
	hud_root.visible = true
	_apply_fast_forward()
	if OS.get_environment("NICESWARM_NET") != "":
		print("[test] start_game peers=%s local=%d host=%s" % [str(peer_ids), local_id, str(is_host())])


## NICESWARM_FF=<mult>: scale the engine clock so a headless host run reaches minute 10 in
## seconds, faithfully (enemies, weapons, spawning, gems all see the scaled delta). Host
## only; players are made immortal (reusing player.debug_god) so the run survives to 10:00,
## and _process prints level/gems each game-minute + auto-resolves level-up picks (no input).
func _apply_fast_forward() -> void:
	var ff := OS.get_environment("NICESWARM_FF")
	if ff == "" or not is_host():
		return
	var mult := maxf(ff.to_float(), 1.0)
	if mult <= 1.0:
		return
	Engine.time_scale = mult
	Engine.max_physics_steps_per_frame = int(ceil(mult)) + 8  # let physics keep pace with the clock
	for id in players:
		var p = players[id]
		if is_instance_valid(p):
			p.debug_god = true
	_ff_min = -1
	print("[ff] fast-forward x%d toward %ds game-time" % [int(mult), int(WIN_TIME)])


func reset_game() -> void:
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
	i_chose = false
	paused_menu = false
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


func _build_world() -> void:
	world = Node2D.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)

	var bg := Background.new()
	bg.arena = ARENA
	world.add_child(bg)

	for i in peer_ids.size():
		var pid: int = peer_ids[i]
		var p := Player.new()
		p.name = "Player_%d" % pid
		p.peer_id = pid
		p.color_idx = i
		p.is_local = pid == local_id
		p.arena = ARENA
		p.position = Vector2.from_angle(TAU * i / maxi(peer_ids.size(), 1)) * 60.0
		p.health_changed.connect(_on_player_hp_changed.bind(p))
		p.died.connect(_on_player_downed.bind(p))
		world.add_child(p)
		players[pid] = p
		_score[pid] = {"damage": 0.0, "xp": 0, "revives": 0, "deaths": 0}
	_grant_starters()


## Decides how each player gets their first weapon. Headless/test runs get a
## fixed loadout (no input available); interactive play opens a "pick 1 of 3
## starting weapons" choice (host-triggered, broadcast like any level-up).
func _grant_starters() -> void:
	var test := OS.get_environment("NICESWARM_TEST")
	var headless := test != "" or OS.get_environment("NICESWARM_NET") != ""
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
			var m := int(elapsed / 60.0)
			if m != _ff_min:
				_ff_min = m
				print("[ff] min=%d level=%d xp_need=%d gems=%d enemies=%d diff=%.1f" \
					% [m, level, _xp_needed(), gems_by_id.size(), enemies_by_id.size(), spawner.difficulty])
	# NICESWARM_FF: auto-resolve level-up picks headless, else the first level-up pauses forever
	if Engine.time_scale > 1.0 and leveling and not i_chose and not current_choices.is_empty():
		_choose_upgrade(0)
	_update_hud()


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

## Host only: a bombardier marks a danger zone; it detonates after TELEGRAPH_WARN
## and hits any player still inside. Synced to clients via STATE_TELEGRAPHS so the
## reacting player sees the warning and can dash out.
func cast_telegraph(pos: Vector2, radius: float, damage: int, effect: int = 0) -> void:
	var tz := TelegraphZone.new()
	tz.radius = radius
	tz.warn = TELEGRAPH_WARN
	tz.damage = damage
	tz.effect = effect
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
	return GameConfig.xp_for_level(level, cfg_xp_rate)


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
	# If any fusion (merge) is on offer, guarantee one shows — fusions are the
	# build payoff and shouldn't be missed to a random shuffle.
	var merges := pool.filter(func(e): return e.get("cat", "") in ["fuse", "amalgam"])
	var rest := pool.filter(func(e): return not (e.get("cat", "") in ["fuse", "amalgam"]))
	rest.shuffle()
	var chosen := []
	if not merges.is_empty():
		merges.shuffle()
		chosen.append(merges[0])
	for e in rest:
		if chosen.size() >= cfg_choices:
			break
		chosen.append(e)
	chosen.shuffle()
	current_choices = chosen.slice(0, cfg_choices)
	for i in choice_buttons.size():
		if i < current_choices.size():
			var u: Dictionary = current_choices[i]
			choice_buttons[i].text = "%d.  %s — %s" % [i + 1, u.name, u.desc]
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


func apply_choice(pid: int, id: String) -> void:
	var p: Player = players.get(pid)
	if p == null:
		return
	if id.begins_with("learn_"):
		p.add_weapon(id.trim_prefix("learn_"))
	elif id.begins_with("merge_"):
		var pair := id.trim_prefix("merge_").split("|")
		if pair.size() == 2:
			p.merge_weapons(pair[0], pair[1])
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
				p.damage_mult *= 1.25
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
	if is_host():
		picked_ids[pid] = true
		_check_all_picked()


func _check_all_picked() -> void:
	if not leveling:
		return
	for pid in peer_ids:
		if not picked_ids.has(pid):
			return
	net.send_resume()
	resume_after_picks()


func resume_after_picks() -> void:
	leveling = false
	picks_starter = false
	level_panel.visible = false
	get_tree().paused = false
	if is_host():
		_maybe_open_picks()  # banked XP or queued chests chain immediately


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
	if game_over:
		return
	game_over = true
	if Engine.time_scale > 1.0:  # NICESWARM_FF: final calibration line, then drop the clock back
		print("[ff] END won=%s min=%.1f level=%d kills=%d gems=%d" \
			% [str(won), elapsed_ / 60.0, level_, kills_, gems_by_id.size()])
		Engine.time_scale = 1.0
	get_tree().paused = true
	end_title.text = "YOU SURVIVED THE NIGHT" if won else "THE PARTY HAS FALLEN"
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
	var header := Label.new()
	header.text = "      PLAYER      DAMAGE     XP    REVIVES   DEATHS"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	scoreboard_box.add_child(header)
	var i := 0
	while i + 4 < scores.size():
		var ci := int(scores[i])
		var col := Player.COLORS[ci % Player.COLORS.size()]
		var row := Label.new()
		row.text = "P%d%s%s%s%s" % [
			ci + 1,
			str(int(round(scores[i + 1]))).lpad(14),
			str(int(scores[i + 2])).lpad(9),
			str(int(scores[i + 3])).lpad(10),
			str(int(scores[i + 4])).lpad(9)]
		row.add_theme_font_size_override("font_size", 20)
		row.add_theme_color_override("font_color", col)
		scoreboard_box.add_child(row)
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
	paused_menu = pause
	get_tree().paused = pause
	if pause:
		_refresh_pause_roster()
	pause_panel.visible = pause


func apply_event(type: int, pos: Vector2) -> void:
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
					pop.color = Color(1.0, 0.3, 0.2)
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
	if key == KEY_F1 and debug_panel != null:
		debug_panel.visible = not debug_panel.visible
		return
	if game_over:
		if key == KEY_R:
			_restart()
		elif key == KEY_M:
			_to_menu()
	elif leveling:
		if key >= KEY_1 and key < KEY_1 + MAX_CHOICES:  # 1..6 select dynamically
			_choose_upgrade(key - KEY_1)
	elif paused_menu:  # while paused, M leaves to the main menu
		if key == KEY_M:
			_to_menu()
		elif key == KEY_ESCAPE and is_host():
			apply_pause(false)
			net.send_set_paused(false)
	elif key == KEY_ESCAPE:
		if is_host():
			apply_pause(true)
			net.send_set_paused(true)
		else:
			_to_menu()  # clients can't pause the host — ESC just leaves the run


## Leave the current run and return to the main menu. Disconnects from co-op
## (host leaving drops everyone; a client leaving just drops itself).
func _to_menu() -> void:
	net.leave()
	get_tree().paused = false
	level_panel.visible = false
	end_panel.visible = false
	pause_panel.visible = false
	paused_menu = false
	_clear_world()
	_show_menu("")


# --- HUD -------------------------------------------------------------------------

func _update_hud() -> void:
	var me: Player = players.get(local_id)
	var t := int(elapsed)
	timer_label.text = "%02d:%02d" % [t / 60, t % 60]
	level_label.text = "Lv %d" % level
	kills_label.text = "Kills %d" % kills
	xp_bar.value = float(xp) / float(maxi(_current_needed(), 1)) * 100.0
	arrows.queue_redraw()
	# difficulty number + bar, with the live heat accelerator (▲ how fast it's climbing)
	var heat := spawner.heat()
	var diff := spawner.diff()
	var filled := clampi(int(diff / 4.0), 0, 8)  # one bar pip per ~4 difficulty, capped at 8
	var bar := "▮".repeat(filled) + "▯".repeat(8 - filled)
	var accel := ""
	if heat >= 0.5:
		accel = "  ▲▲"
	elif heat >= 0.15:
		accel = "  ▲"
	threat_label.text = "DIFFICULTY %.1f  %s%s" % [diff, bar, accel]
	threat_label.add_theme_color_override("font_color",
		Color(1.0, 0.4, 0.35) if heat >= 0.5 else (Color(1.0, 0.8, 0.4) if heat >= 0.15 else Color(0.7, 0.75, 0.85)))
	if me == null:
		return
	if me.downed:
		hp_label.text = "DOWNED — ally can revive you"
	else:
		hp_label.text = "♥".repeat(maxi(me.hp, 0)) + "♡".repeat(me.max_hp - maxi(me.hp, 0))
	if me.dash_timer <= 0.0:
		dash_label.text = "Dash READY"
		dash_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.7))
	else:
		dash_label.text = "Dash %.1fs" % me.dash_timer
		dash_label.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7))
	var wparts := []
	for w in me.weapons:
		wparts.append("%s %d" % [w.display_name, w.level])
	weapons_label.text = "  ·  ".join(wparts)
	var lines := []
	for pid in peer_ids:
		if pid == local_id:
			continue
		var p: Player = players.get(pid)
		if p == null:
			continue
		if p.downed:
			lines.append("P%d  DOWN %d%%" % [p.color_idx + 1, int(p.revive_progress * 100.0)])
		else:
			lines.append("P%d  ♥%d/%d" % [p.color_idx + 1, p.hp, p.max_hp])
	allies_label.text = "\n".join(lines)


func _draw_ally_arrows() -> void:
	if not playing:
		return
	var me: Player = players.get(local_id)
	if me == null:
		return
	var size := arrows.get_viewport_rect().size
	var xform := get_viewport().get_canvas_transform()
	for pid in peer_ids:
		if pid == local_id:
			continue
		var p: Player = players.get(pid)
		if p == null:
			continue
		var sp: Vector2 = xform * p.global_position
		if Rect2(Vector2.ZERO, size).grow(-24.0).has_point(sp):
			continue
		var c := sp.clamp(Vector2(40.0, 40.0), size - Vector2(40.0, 40.0))
		var dir := (sp - c).normalized()
		if dir == Vector2.ZERO:
			continue
		var col := Player.COLORS[p.color_idx % Player.COLORS.size()]
		var tip := c + dir * 16.0
		var side := dir.orthogonal() * 9.0
		arrows.draw_polygon(PackedVector2Array([tip, c - dir * 4.0 + side, c - dir * 4.0 - side]),
			PackedColorArray([col]))


# --- UI construction --------------------------------------------------------------

func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)

	hud_root = Control.new()
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud_root)

	xp_bar = ProgressBar.new()
	xp_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	xp_bar.offset_bottom = 12.0
	xp_bar.show_percentage = false
	hud_root.add_child(xp_bar)

	hp_label = _make_label(Vector2(16, 20), 30, Color(1.0, 0.35, 0.4))
	timer_label = _make_label(Vector2(600, 20), 30, Color.WHITE)
	level_label = _make_label(Vector2(16, 58), 22, Color(0.8, 0.85, 1.0))
	kills_label = _make_label(Vector2(16, 86), 22, Color(0.8, 0.85, 1.0))
	dash_label = _make_label(Vector2(16, 114), 22, Color(0.5, 1.0, 0.7))
	threat_label = _make_label(Vector2(540, 58), 22, Color(0.6, 0.65, 0.75))
	allies_label = _make_label(Vector2(16, 146), 20, Color(0.85, 0.85, 0.95))
	weapons_label = _make_label(Vector2.ZERO, 18, Color(0.75, 0.8, 0.9))
	weapons_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	weapons_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	weapons_label.offset_top = 20.0
	weapons_label.offset_right = -16.0
	weapons_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var hint := _make_label(Vector2(16, 690), 16, Color(0.5, 0.55, 0.65))
	hint.text = "WASD move  ·  SPACE/SHIFT dash  ·  revive a downed ally by standing near  ·  ESC pause/menu"

	arrows = Control.new()
	arrows.set_anchors_preset(Control.PRESET_FULL_RECT)
	arrows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrows.draw.connect(_draw_ally_arrows)
	hud_root.add_child(arrows)

	_build_level_panel()
	_build_end_panel()
	_build_pause_panel()
	_build_menu()
	if OS.is_debug_build():
		_build_debug_panel()


func _make_label(pos: Vector2, size: int, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	hud_root.add_child(l)
	return l


func _make_overlay() -> Array:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	ui.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)
	return [root, vbox]


func _build_level_panel() -> void:
	var parts := _make_overlay()
	level_panel = parts[0]
	var vbox: VBoxContainer = parts[1]
	panel_title = Label.new()
	panel_title.add_theme_font_size_override("font_size", 34)
	panel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(panel_title)
	for i in MAX_CHOICES:
		var b := Button.new()
		b.custom_minimum_size = Vector2(640, 56)
		b.add_theme_font_size_override("font_size", 21)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.clip_text = false
		b.pressed.connect(_choose_upgrade.bind(i))
		vbox.add_child(b)
		choice_buttons.append(b)


func _build_end_panel() -> void:
	var parts := _make_overlay()
	end_panel = parts[0]
	var vbox: VBoxContainer = parts[1]
	end_title = Label.new()
	end_title.add_theme_font_size_override("font_size", 52)
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(end_title)
	end_stats = Label.new()
	end_stats.add_theme_font_size_override("font_size", 24)
	end_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(end_stats)
	scoreboard_box = VBoxContainer.new()
	scoreboard_box.add_theme_constant_override("separation", 4)
	vbox.add_child(scoreboard_box)
	end_hint = Label.new()
	end_hint.add_theme_font_size_override("font_size", 20)
	end_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(end_hint)


func _build_pause_panel() -> void:
	var parts := _make_overlay()
	pause_panel = parts[0]
	var vbox: VBoxContainer = parts[1]
	var l := Label.new()
	l.text = "PAUSED"
	l.add_theme_font_size_override("font_size", 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(l)

	var loadout_head := Label.new()
	loadout_head.text = "YOUR LOADOUT"
	loadout_head.add_theme_font_size_override("font_size", 20)
	loadout_head.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	loadout_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(loadout_head)
	pause_loadout = Label.new()
	pause_loadout.add_theme_font_size_override("font_size", 20)
	pause_loadout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(pause_loadout)

	var roster_head := Label.new()
	roster_head.text = "ARSENAL"
	roster_head.add_theme_font_size_override("font_size", 20)
	roster_head.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	roster_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(roster_head)
	pause_roster = Label.new()
	pause_roster.add_theme_font_size_override("font_size", 17)
	pause_roster.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(pause_roster)

	var foot := Label.new()
	foot.text = "ESC resume  ·  M main menu"
	foot.add_theme_font_size_override("font_size", 16)
	foot.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(foot)


## Debug-build-only testing panel: F1 toggles it. God mode + one-click weapon
## grant/level-up for the local player, routed through the normal upgrade-pick
## RPC so co-op peers stay in sync.
func _build_debug_panel() -> void:
	debug_panel = Control.new()
	debug_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	debug_panel.offset_left = -260.0
	debug_panel.offset_right = -16.0
	debug_panel.offset_top = 100.0
	debug_panel.offset_bottom = 640.0
	debug_panel.visible = false
	ui.add_child(debug_panel)

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	debug_panel.add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(8, 8)
	debug_panel.add_child(vbox)

	var title := Label.new()
	title.text = "DEBUG (F1)"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	vbox.add_child(title)

	debug_god_btn = Button.new()
	debug_god_btn.text = "God Mode: OFF"
	debug_god_btn.pressed.connect(_debug_toggle_god)
	vbox.add_child(debug_god_btn)

	var levelup_btn := Button.new()
	levelup_btn.text = "Instant Level Up"
	levelup_btn.pressed.connect(_debug_level_up)
	vbox.add_child(levelup_btn)

	var reset_btn := Button.new()
	reset_btn.text = "Reset Weapons + Stats"
	reset_btn.pressed.connect(_debug_reset_loadout)
	vbox.add_child(reset_btn)

	var grant_head := Label.new()
	grant_head.text = "Grant / level weapon"
	grant_head.add_theme_font_size_override("font_size", 14)
	grant_head.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	vbox.add_child(grant_head)

	var grid := GridContainer.new()
	grid.columns = 4
	vbox.add_child(grid)
	for wid in WEAPON_INFO:
		var b := Button.new()
		b.text = wid
		b.add_theme_font_size_override("font_size", 12)
		b.custom_minimum_size = Vector2(56, 26)
		b.pressed.connect(_debug_grant_weapon.bind(wid))
		grid.add_child(b)

	var fuse_head := Label.new()
	fuse_head.text = "Grant fusion"
	fuse_head.add_theme_font_size_override("font_size", 14)
	fuse_head.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	vbox.add_child(fuse_head)

	var fuse_row := HBoxContainer.new()
	vbox.add_child(fuse_row)
	debug_fuse_a = OptionButton.new()
	debug_fuse_b = OptionButton.new()
	for wid in WEAPON_INFO:
		debug_fuse_a.add_item(wid)
		debug_fuse_b.add_item(wid)
	debug_fuse_b.selected = 1
	fuse_row.add_child(debug_fuse_a)
	fuse_row.add_child(debug_fuse_b)
	var fuse_btn := Button.new()
	fuse_btn.text = "Fuse"
	fuse_btn.pressed.connect(_debug_grant_fusion)
	vbox.add_child(fuse_btn)

	var stat_head := Label.new()
	stat_head.text = "Stat up"
	stat_head.add_theme_font_size_override("font_size", 14)
	stat_head.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	vbox.add_child(stat_head)

	var stat_grid := GridContainer.new()
	stat_grid.columns = 4
	vbox.add_child(stat_grid)
	for sid in STAT_INFO:
		var sb := Button.new()
		sb.text = STAT_INFO[sid]
		sb.add_theme_font_size_override("font_size", 12)
		sb.custom_minimum_size = Vector2(56, 26)
		sb.pressed.connect(_debug_stat_up.bind(sid))
		stat_grid.add_child(sb)


func _debug_toggle_god() -> void:
	var p: Player = players.get(local_id)
	if p == null:
		return
	p.debug_god = not p.debug_god
	debug_god_btn.text = "God Mode: ON" if p.debug_god else "God Mode: OFF"


## Grants the weapon if the local player doesn't have it yet, otherwise
## levels it up (capped at MAX_WEAPON_LEVEL) — handy for testing fusions.
func _debug_grant_weapon(id: String) -> void:
	var p: Player = players.get(local_id)
	if p == null:
		return
	var w := p.get_weapon(id)
	if w == null:
		net.submit_choice(local_id, "learn_" + id)
	elif w.level < MAX_WEAPON_LEVEL:
		net.submit_choice(local_id, "lv_" + id)


func _debug_stat_up(id: String) -> void:
	if players.get(local_id) == null:
		return
	net.submit_choice(local_id, id)


## Strips the local player of every weapon (including the starting bolt) and
## resets every stat multiplier to its starting value — a clean slate for
## re-testing weapons without restarting the run.
func _debug_reset_loadout() -> void:
	var p: Player = players.get(local_id)
	if p == null:
		return
	for w in p.weapons:
		w.queue_free()
	p.weapons.clear()
	p.damage_mult = 1.0
	p.rate_mult = 1.0
	p.area_mult = 1.0
	p.duration_mult = 1.0
	p.move_speed = 220.0
	p.pickup_range = 90.0
	p.dash_cooldown = 2.5
	p.max_hp = 5
	p.hp = mini(p.hp, p.max_hp)
	p.health_changed.emit(p.hp, p.max_hp)


## Force the party to its next level-up pick immediately (host-only — the
## same path real XP gain uses, so picks/sync behave normally).
func _debug_level_up() -> void:
	if not is_host() or leveling or game_over:
		return
	xp = _xp_needed()
	_maybe_open_picks()


## Maxes both selected weapons (granting them first if missing) and fuses
## them — signature recipe if one exists, otherwise the generic WeaponFused.
func _debug_grant_fusion() -> void:
	var a := debug_fuse_a.get_item_text(debug_fuse_a.selected)
	var b := debug_fuse_b.get_item_text(debug_fuse_b.selected)
	if a == b:
		return
	var p: Player = players.get(local_id)
	if p == null:
		return
	for id in [a, b]:
		_debug_grant_weapon(id)
		var w := p.get_weapon(id)
		while w != null and w.level < MAX_WEAPON_LEVEL:
			net.submit_choice(local_id, "lv_" + id)
			w = p.get_weapon(id)
	net.submit_choice(local_id, "merge_" + Fusions.key(a, b))


func _refresh_pause_roster() -> void:
	var me: Player = players.get(local_id)
	if me == null:
		return
	var loadout := []
	for w in me.weapons:
		loadout.append("%s — Lv %d" % [w.display_name, w.level])
	pause_loadout.text = "\n".join(loadout) if not loadout.is_empty() else "—"

	# which base weapons are absorbed into a fusion
	var fused_ids := {}
	for w in me.weapons:
		if w is WeaponFused:
			for c in w.components:
				fused_ids[c.weapon_id] = true

	var lines := []
	var row := []
	var i := 0
	for wid in WEAPON_INFO:
		var status: String
		var owned := me.get_weapon(wid)
		if owned != null:
			status = "Lv %d" % owned.level
		elif fused_ids.has(wid):
			status = "fused"
		else:
			status = "—"
		row.append((WEAPON_INFO[wid].name as String).rpad(17) + status)
		i += 1
		if row.size() == 2:  # two weapons per line
			lines.append("   ".join(row))
			row = []
	if not row.is_empty():
		lines.append("   ".join(row))
	pause_roster.text = "\n".join(lines)


## A label + a button that cycles an option; `get_text` returns the current value
## string, `advance` steps to the next. The button relabels itself on each press.
func _make_cycler(parent: Node, label: String, get_text: Callable, advance: Callable) -> void:
	var row := HBoxContainer.new()
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
	b.text = get_text.call()
	b.pressed.connect(func():
		advance.call()
		b.text = get_text.call())
	row.add_child(b)


func _build_menu() -> void:
	var parts := _make_overlay()
	menu_panel = parts[0]
	menu_panel.visible = true
	var vbox: VBoxContainer = parts[1]

	var title := Label.new()
	title.text = "NICESWARM"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "co-op arena survival   ·   v%s" % VERSION
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)

	var solo := Button.new()
	solo.text = "Play Solo"
	solo.custom_minimum_size = Vector2(360, 52)
	solo.add_theme_font_size_override("font_size", 22)
	solo.pressed.connect(_on_solo_pressed)
	vbox.add_child(solo)

	var host := Button.new()
	host.text = "Host Co-op"
	host.custom_minimum_size = Vector2(360, 52)
	host.add_theme_font_size_override("font_size", 22)
	host.pressed.connect(_on_host_pressed)
	vbox.add_child(host)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vbox.add_child(row)
	ip_edit = LineEdit.new()
	ip_edit.text = "127.0.0.1"
	ip_edit.custom_minimum_size = Vector2(252, 52)
	ip_edit.add_theme_font_size_override("font_size", 20)
	row.add_child(ip_edit)
	var join := Button.new()
	join.text = "Join"
	join.custom_minimum_size = Vector2(100, 52)
	join.add_theme_font_size_override("font_size", 22)
	join.pressed.connect(_on_join_pressed)
	row.add_child(join)

	var port_row := HBoxContainer.new()
	port_row.add_theme_constant_override("separation", 8)
	vbox.add_child(port_row)
	var port_label := Label.new()
	port_label.text = "Port"
	port_label.add_theme_font_size_override("font_size", 20)
	port_label.custom_minimum_size = Vector2(100, 40)
	port_row.add_child(port_label)
	port_edit = LineEdit.new()
	port_edit.text = str(Net.PORT)
	port_edit.custom_minimum_size = Vector2(252, 40)
	port_edit.add_theme_font_size_override("font_size", 20)
	port_row.add_child(port_edit)

	# difficulty config cyclers (used by Solo and Host)
	_make_cycler(vbox, "Options / level-up", func(): return str(CHOICES_OPTS[cfg_choices_i]),
		func(): cfg_choices_i = (cfg_choices_i + 1) % CHOICES_OPTS.size())
	_make_cycler(vbox, "XP rate", func(): return str(XP_OPTS[cfg_xp_i]) + "x",
		func(): cfg_xp_i = (cfg_xp_i + 1) % XP_OPTS.size())
	_make_cycler(vbox, "Enemy scale", func(): return str(SCALE_OPTS[cfg_scale_i]) + "x",
		func(): cfg_scale_i = (cfg_scale_i + 1) % SCALE_OPTS.size())

	start_btn = Button.new()
	start_btn.text = "Start Game"
	start_btn.custom_minimum_size = Vector2(360, 52)
	start_btn.add_theme_font_size_override("font_size", 22)
	start_btn.visible = false
	start_btn.pressed.connect(_on_start_pressed)
	vbox.add_child(start_btn)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(status_label)
