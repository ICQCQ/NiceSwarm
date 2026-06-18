class_name SimDriver
extends Node
## Headless test harness: NICESWARM_SIM autopilot playstyle runs + NICESWARM_FF
## fast-forward instrumentation. Lives as a child of Main (like EnemySpawner/Net),
## holding a `main` back-reference. Gated entirely by env vars — zero cost in normal
## play (no method here runs unless its env var is set).

var main: Node

# --- NICESWARM_SIM autopilot state ---
var active := false      # a sim run is in progress; prints one [sim] line then quits
var style := ""
var seed_val := 0
var age_sum := 0.0       # sum of enemy ages at death -> average time-to-kill

# --- NICESWARM_FF state ---
var ff_min := -1         # last game-minute printed during a fast-forward run
var ff_lethal_prev := 0.0  # cumulative party lethal_taken at the last per-minute print
var god_mode := false    # NICESWARM_SIM god=1: bots immortal so they reach the late game (lethality probe)

# Headless playstyle sims (NICESWARM_SIM): each style = priority weapons to learn/level
# toward, plus the fusion to aim for. pick_for follows this when auto-resolving level-ups.
const STYLES := {
	"railgun":   {"prio": ["bolt", "lightning"], "fuse": ["bolt", "lightning"]},
	"pulsar":    {"prio": ["nova", "orbit"], "fuse": ["nova", "orbit"]},
	"supernova": {"prio": ["flame", "nova"], "fuse": ["flame", "nova"]},
	"glacier":   {"prio": ["frost", "gravity"], "fuse": ["frost", "gravity"]},
	"prism":     {"prio": ["laser", "orbit"], "fuse": ["laser", "orbit"]},
	"toxicpyre": {"prio": ["flame", "venom"], "fuse": ["flame", "venom"]},
	"warhead":   {"prio": ["missiles", "nova"], "fuse": ["missiles", "nova"]},
	"singular":  {"prio": ["gravity", "nova"], "fuse": ["gravity", "nova"]},
	"cluster":   {"prio": ["mines", "missiles"], "fuse": ["mines", "missiles"]},
	"storm":     {"prio": ["glaive", "lightning"], "fuse": ["glaive", "lightning"]},
	"frostbite": {"prio": ["frost", "venom"], "fuse": ["frost", "venom"]},
	"groundcurrent": {"prio": ["lightning", "venom"], "fuse": ["lightning", "venom"]},
	"greedy":    {"prio": ["bolt", "orbit", "nova", "flame", "frost"], "fuse": []},
}


# --- NICESWARM_SIM: autopilot playstyle run ---------------------------------

## NICESWARM_SIM="style=railgun,players=2,seed=3,ff=40": a headless autopilot run. Spawns N
## kiting-bot players, follows the playstyle's pick priority, and on win/wipe prints one [sim]
## line then quits. Mortal (no god mode) so "how far does this build get" is a real result.
func start() -> void:
	var cfg := {}
	for kv in OS.get_environment("NICESWARM_SIM").split(",", false):
		var p := kv.split("=")
		if p.size() == 2:
			cfg[p[0].strip_edges()] = p[1].strip_edges()
	active = true
	style = cfg.get("style", "greedy")
	seed_val = int(cfg.get("seed", "1"))
	seed(seed_val)  # reproducible enemy field per seed (overrides _ready's randomize())
	var n := clampi(int(cfg.get("players", "1")), 1, 4)
	var ff := maxf(float(cfg.get("ff", "40")), 1.0)
	main.local_id = 1
	var ids := []
	for i in n:
		ids.append(i + 1)
	main.start_game(ids)
	god_mode = cfg.get("god", "0") == "1"
	for pid in main.players:
		main.players[pid].bot = true  # host drives every player as a kiting bot
		if god_mode:
			main.players[pid].debug_god = true  # immortal kiter: reaches 10:00, lethal_taken tallies the would-be damage
	Engine.time_scale = ff
	# Effectively uncap physics steps/frame so heavy late-game frames never under-simulate
	# (time-dilate) and skew the result; when the CPU can't keep up the run just stretches in
	# wall-clock, faithfully. Pick a modest ff so it stays close to real-time.
	Engine.max_physics_steps_per_frame = 100000


## Host: during a sim level-up, resolve one not-yet-chosen player per frame (the wait-for-all
## flow then resumes / chains naturally). One per frame avoids re-entrancy with chained picks.
func autopick() -> void:
	for pid in main.peer_ids:
		if not main.picked_ids.has(pid):
			main.apply_choice(pid, pick_for(main.players[pid]))
			return


## The id this playstyle picks from a freshly-rolled option set for player p.
func pick_for(p: Player) -> String:
	var s: Dictionary = STYLES.get(style, STYLES["greedy"])
	var opts := roll(p)
	var best_id := ""
	var best := -1.0
	for c in opts:
		var sc := score(c, s.prio, s.fuse)
		if sc > best:
			best = sc
			best_id = c.id
	return best_id if best_id != "" else ("st_power" if opts.is_empty() else opts[0].id)


## A realistic option set for player p — like _roll_choices (merge guaranteed, cfg_choices wide),
## but for any player and returned rather than shown on a panel.
func roll(p: Player) -> Array:
	var pool: Array = main._build_choice_pool(p)
	var merges: Array = pool.filter(func(e): return e.get("cat", "") in ["fuse", "amalgam"])
	var rest: Array = pool.filter(func(e): return not (e.get("cat", "") in ["fuse", "amalgam"]))
	rest.shuffle()
	var chosen := []
	if not merges.is_empty():
		merges.shuffle()
		chosen.append(merges[0])
	for e in rest:
		if chosen.size() >= main.cfg_choices:
			break
		chosen.append(e)
	return chosen


## Score an option for the active playstyle: fuse-to-target >> level/learn priority weapons >>
## power/survival stats >> off-build picks.
func score(c: Dictionary, prio: Array, fuse: Array) -> float:
	var id: String = c.id
	if id.begins_with("merge_"):
		var pair := id.trim_prefix("merge_").split("|")
		if fuse.size() == 2 and pair.has(fuse[0]) and pair.has(fuse[1]):
			return 100.0  # exactly the fusion this build wants
		return 30.0       # some other fusion — still strong
	if id.begins_with("learn_"):
		var wid := id.trim_prefix("learn_")
		if wid in prio:
			return 80.0 - float(prio.find(wid))
		if wid in fuse:
			return 78.0
		return 6.0
	if id.begins_with("lv_"):
		var wid := id.trim_prefix("lv_")
		if wid in prio or wid in fuse:
			return 70.0   # push toward MAX so the fusion unlocks
		return 42.0       # leveling the fusion product / anything owned
	match id:
		"st_hp": return 48.0      # survival-capped bot: stack max HP first
		"st_power": return 36.0
		"st_speed": return 34.0
		"st_dash": return 32.0
		"st_rate": return 28.0
		"st_area": return 24.0
		"st_duration": return 18.0
	return 12.0


## Called from main.apply_end. Handles the sim/FF end-of-run lines and returns true
## iff the run should early-return (a sim run quits the process here).
func report_end(won: bool, elapsed_: float, level_: int, kills_: int) -> bool:
	if active:
		var ttk := age_sum / float(maxi(kills_, 1))
		print("[sim] style=%s party=%d seed=%d result=%s time=%.1f diff=%.1f level=%d kills=%d ttk=%.2f lethal=%.0f%s" \
			% [style, main.peer_ids.size(), seed_val, ("WIN" if won else "DEAD"), elapsed_, main.spawner.diff(), level_, kills_, ttk, _party_lethal(), (" GOD" if god_mode else "")])
		main.get_tree().quit(0)
		return true
	if Engine.time_scale > 1.0:  # NICESWARM_FF: final calibration line, then drop the clock back
		print("[ff] END won=%s min=%.1f level=%d kills=%d gems=%d" \
			% [str(won), elapsed_ / 60.0, level_, kills_, main.gems_by_id.size()])
		Engine.time_scale = 1.0
	return false


## Sum of would-be damage every player has eaten (lethal_taken). Only meaningful with
## immortal players (god/FF) — the late-game incoming-DPS-to-a-5HP-player probe.
func _party_lethal() -> float:
	var total := 0.0
	for pid in main.players:
		var p = main.players[pid]
		if is_instance_valid(p):
			total += p.lethal_taken
	return total


# --- NICESWARM_FF: fast-forward instrumentation -----------------------------

## NICESWARM_FF=<mult>: scale the engine clock so a headless host run reaches minute 10 in
## seconds, faithfully (enemies, weapons, spawning, gems all see the scaled delta). Host
## only; players are made immortal (reusing player.debug_god) so the run survives to 10:00,
## and _process prints level/gems each game-minute + auto-resolves level-up picks (no input).
func apply_fast_forward() -> void:
	var ff := OS.get_environment("NICESWARM_FF")
	if ff == "" or not main.is_host():
		return
	var mult := maxf(ff.to_float(), 1.0)
	if mult <= 1.0:
		return
	Engine.time_scale = mult
	Engine.max_physics_steps_per_frame = int(ceil(mult)) + 8  # let physics keep pace with the clock
	for id in main.players:
		var p = main.players[id]
		if is_instance_valid(p):
			p.debug_god = true
	ff_min = -1
	print("[ff] fast-forward x%d toward %ds game-time" % [int(mult), int(GameConfig.WIN_TIME)])


## Per-minute fast-forward progress log (called from main._process while time_scale > 1).
func ff_minute_log() -> void:
	var m := int(main.elapsed / 60.0)
	if m == ff_min:
		return
	ff_min = m
	var lethal_now := _party_lethal()
	print("[ff] min=%d level=%d xp_need=%d gems=%d enemies=%d diff=%.1f lethal/min=%.0f (5hp player)" \
		% [m, main.level, main._xp_needed(), main.gems_by_id.size(), main.enemies_by_id.size(), main.spawner.difficulty, lethal_now - ff_lethal_prev])
	ff_lethal_prev = lethal_now
	var p0 = main.players.get(1)
	if p0 != null and is_instance_valid(p0):
		var wl := PackedStringArray()
		for w in p0.weapons:
			wl.append("%s:L%d" % [w.weapon_id, w.level])
		print("[ff]   loadout: %s" % ", ".join(wl))
	print("[ff]   census: %s" % ff_census())


## NICESWARM_FF instrumentation: walk the live world subtree once and tally spawned
## nodes by script file, so the per-minute log shows WHICH node types dominate late
## game (the suspected 8-min cost). Also reports total node count + physics frame time.
func ff_census() -> String:
	if main.world == null or not is_instance_valid(main.world):
		return "no world"
	var counts := {}
	var total := 0
	var stack: Array = [main.world]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.push_back(c)
			total += 1
			var s = c.get_script()
			if s != null and s.resource_path != "":
				var key: String = s.resource_path.get_file().trim_suffix(".gd")
				counts[key] = int(counts.get(key, 0)) + 1
	var keys := counts.keys()
	keys.sort_custom(func(a, b): return counts[a] > counts[b])
	var parts := PackedStringArray()
	for k in keys:
		if int(counts[k]) >= 3:  # drop singletons (player/weapons) — keep the spawn-heavy types
			parts.append("%s=%d" % [k, counts[k]])
	var phys := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	return "nodes=%d phys=%.2fms | %s" % [total, phys, ", ".join(parts)]


# --- NICESWARM_DMGTABLE: per-weapon full-swarm damage/min reference table -----
## NICESWARM_DMGTABLE=1: boot solo, build a STATIC immortal enemy disc around the player,
## then equip each weapon (13 base + every signature fusion) at each level 1..MAX one at a
## time and measure total damage dealt to the swarm over DMG_WINDOW game-seconds — direct
## (via take_hit -> _score) + burn DoT (via add_burn_damage -> _burn_total). Prints one
## "[dmg] base|<id>|L<n>|<dpm>|<name>" / "[dmg] fus|<a|b>|L<n>|<dpm>|<name>" line per cell.
## Party level held at 1 and all stat mults at baseline so each row is the weapon's intrinsic
## scaling. Field is uniform (stated density) — every AoE number scales ~linearly with it.
const DMG_FIELD_RADIUS := 360.0   # uniform immortal disc around the player (covers near-player AoE)
const DMG_FIELD_SPACING := 45.0   # ~1.6 enemy-diameters (enemy radius 14) — a dense but un-stacked pack
const DMG_BASE_WEAPONS := ["bolt", "orbit", "nova", "glaive", "lightning", "flame",
	"mines", "missiles", "laser", "frost", "gravity", "turret", "venom"]


## Field enemy that tallies EVERY hit at the one universal chokepoint (enemy.take_hit) —
## so the measurement is independent of each weapon's source_pid / damage_dealt plumbing
## (some credit _score, some credit damage_dealt, burn DoT routes a take_hit(DMG_FIRE) too).
## Capturing the raw `amount` here counts all of it exactly once.
class DmgDummy extends Enemy:
	static var total: float = 0.0
	func take_hit(amount: float, from_pos: Variant = null, dtype: int = Enemy.DMG_PHYS, source_pid: int = -1) -> void:
		total += amount
		super(amount, from_pos, dtype, source_pid)

var _dmg_window := 60.0    # game-seconds per cell (override: NICESWARM_DMGW=<sec>)
var _dmg_active := false
var _dmg_cells: Array = []  # each: {"kind": "base"/"fus", "a": id, "b": id, "lvl": int}
var _dmg_i := -1
var _dmg_t := 0.0
var _dmg_phase := 0         # 0 = equip+reset, 1 = accumulate window, 2 = clear+settle then advance
var _dmg_p: Player
var _dmg_w: WeaponBase
var _dmg_center := Vector2.ZERO  # field anchor; the player orbits this so movement-gated
var _dmg_clock := 0.0            # weapons (venom trail) fire and moving-origin weapons stay centered


func run_dmg_table() -> void:
	main.local_id = 1
	main.start_game([1])
	seed(424242)                          # deterministic spread/mine-offset RNG
	var wenv := OS.get_environment("NICESWARM_DMGW")
	if wenv != "":
		_dmg_window = maxf(wenv.to_float(), 1.0)
	# Fast-forward WITHOUT tunneling: per-tick delta = time_scale / physics_ticks_per_second.
	# At the stock 60/60 that's delta=1.0, so a 520 px/s bolt jumps 520 px/tick and flies clean
	# past the 45 px-spaced field (every moving-hit-volume weapon — bolt/glaive/missiles/frost/
	# turret projectiles — reads 0). Raising the tick rate in lockstep keeps delta at the normal
	# 1/60 (projectiles step ~9 px/tick, collisions register) while still advancing `time_scale`
	# game-seconds per real second. Fixed-radius weapons (nova/orbit/flame/...) are step-agnostic.
	var tsenv := OS.get_environment("NICESWARM_DMGTS")
	var ts := maxf(tsenv.to_float(), 1.0) if tsenv != "" else 30.0
	Engine.time_scale = ts
	Engine.physics_ticks_per_second = int(60.0 * ts)  # -> delta stays 1/60
	Engine.max_physics_steps_per_frame = 100000
	Engine.max_fps = 0
	main.cfg_win_time = 1.0e12            # never enter the final stage during the sweep
	main.debug_no_spawn = true            # only our static field — no organic spawns
	main.debug_immortal_enemies = true    # hp resets to max each hit -> full damage credited
	main.level = 1                        # party level 1: isolate the weapon's OWN level
	_dmg_p = main.players[1]
	_dmg_p.debug_god = true
	_dmg_p.bot = true            # bot drives real movement (move_and_slide) -> nonzero velocity for venom
	_dmg_p.power_stat = 1.0
	_dmg_p.area_mult = 1.0
	_dmg_p.rate_mult = 1.0
	_dmg_p.duration_mult = 1.0
	for w in _dmg_p.weapons.duplicate():  # drop the auto-granted starter loadout
		w.queue_free()
	_dmg_p.weapons.clear()
	_dmg_center = _dmg_p.global_position
	_dmg_build_field(_dmg_p)
	for wid in DMG_BASE_WEAPONS:
		for lvl in range(1, GameConfig.MAX_WEAPON_LEVEL + 1):
			_dmg_cells.append({"kind": "base", "a": wid, "b": "", "lvl": lvl})
	for key in Fusions.INFO.keys():
		var pair: PackedStringArray = key.split("|")
		for lvl in range(1, GameConfig.MAX_WEAPON_LEVEL + 1):
			_dmg_cells.append({"kind": "fus", "a": pair[0], "b": pair[1], "lvl": lvl})
	await get_tree().physics_frame        # register the field in the spatial grid before measuring
	var field_n: int = get_tree().get_nodes_in_group("enemies").size()
	print("[dmg] FIELD radius=%.0f spacing=%.0f count=%d window=%.0fs cells=%d party_level=1 stats=baseline" \
		% [DMG_FIELD_RADIUS, DMG_FIELD_SPACING, field_n, _dmg_window, _dmg_cells.size()])
	_dmg_phase = 2                        # advance into the first cell on the next physics tick
	_dmg_active = true


## Fast-forwarded measurement state machine, driven at the time-scaled physics rate (like FF
## mode). Stepping via _physics_process — NOT `await physics_frame` — is what lets time_scale
## actually fast-forward: an await coroutine resumes only once per rendered frame (~real-time),
## while _physics_process is called on every (scaled) physics tick.
func _physics_process(delta: float) -> void:
	if not _dmg_active:
		return
	if _dmg_i <= 0 and OS.get_environment("NICESWARM_DMGDBG") == "1":
		print("[dmg] DBG delta=%.5f phys_ticks=%d time_scale=%.1f" % [delta, Engine.physics_ticks_per_second, Engine.time_scale])
	# Keep the player near the field center but always MOVING (real velocity), so trail weapons
	# (venom) that only drop while moving still fire. The bot drives velocity via move_and_slide
	# (input-driven velocity gets zeroed each tick — see player._physics_process); we just tug it
	# back toward center if the kite wanders out of the dense disc.
	if _dmg_p.global_position.distance_to(_dmg_center) > DMG_FIELD_RADIUS * 0.4:
		_dmg_p.global_position = _dmg_center
	match _dmg_phase:
		0:  # equip the cell's weapon at its level, reset the damage accumulators
			_dmg_equip(_dmg_cells[_dmg_i])
			DmgDummy.total = 0.0           # tallies all damage to the swarm via take_hit
			_dmg_t = 0.0
			_dmg_phase = 1
		1:  # accumulate one window of game-time, then record + tear down
			_dmg_t += delta
			if _dmg_t >= _dmg_window:
				var cell: Dictionary = _dmg_cells[_dmg_i]
				var dpm: float = DmgDummy.total * (60.0 / _dmg_window)  # normalize to damage-per-minute
				var nm := "?" if _dmg_w == null else _dmg_w.display_name
				if OS.get_environment("NICESWARM_DMGDBG") == "1":
					var nsp := 0
					for c in main.world.get_children():
						if not (c is Player) and not c.is_in_group("enemies"):
							nsp += 1
					print("[dmg]   DIAG spawned=%d egrid=%d wlevel=%d" % [nsp, EnemyGrid.all().size(), main.level])
				if cell.kind == "base":
					print("[dmg] base|%s|L%d|%.1f|%s" % [cell.a, cell.lvl, dpm, nm])
				else:
					print("[dmg] fus|%s|%s|L%d|%.1f|%s" % [cell.a, cell.b, cell.lvl, dpm, nm])
				_dmg_clear()
				_dmg_phase = 2
		2:  # one settle tick (queued frees flush) then advance to the next cell / finish
			_dmg_i += 1
			if _dmg_i >= _dmg_cells.size():
				print("[dmg] DONE")
				_dmg_active = false
				get_tree().quit(0)
				return
			_dmg_phase = 0


## Equip the single weapon for `cell` (a fresh signature fusion is built exactly as
## player.merge_weapons does: tier 1 + born_dmg + born_count_floor).
func _dmg_equip(cell: Dictionary) -> void:
	if cell.kind == "base":
		_dmg_p.add_weapon(cell.a)
		_dmg_w = _dmg_p.weapons[_dmg_p.weapons.size() - 1]
		_dmg_w.level = cell.lvl
		return
	var f: WeaponBase = Fusions.make(cell.a, cell.b)
	_dmg_w = f
	if f == null:
		return
	f.tier = 1
	f.born_dmg = GameConfig.FUSION_BORN_DMG
	f.born_count_floor = GameConfig.FUSION_BORN_COUNT_FLOOR
	f.level = cell.lvl
	_dmg_p.add_child(f)
	_dmg_p.weapons.append(f)


## Uniform immortal, stationary enemy disc centered on the player.
func _dmg_build_field(p: Player) -> void:
	var r2 := DMG_FIELD_RADIUS * DMG_FIELD_RADIUS
	var s := DMG_FIELD_SPACING
	var n := int(DMG_FIELD_RADIUS / s) + 1
	for ix in range(-n, n + 1):
		for iy in range(-n, n + 1):
			var off := Vector2(ix * s, iy * s)
			var d2 := off.length_squared()
			if d2 > r2 or d2 < 400.0:          # inside the disc, but not on top of the player
				continue
			var e := DmgDummy.new()
			e.main_ref = main
			e.type_id = 0
			e.max_hp = 1.0e9
			e.hp = 1.0e9
			e.radius = 14.0
			e.speed = 0.0                      # stationary (velocity = move*0 + knockback)
			e.move_mode = 0
			e.life = 0.0                       # no expiry
			e.cc_immune = true                 # no slow/knockback drift...
			e.knockback_immune = true          # ...so the field geometry stays fixed...
			e.pull_immune = true               # ...even under gravity wells
			e.color = Color(0.8, 0.3, 0.3)
			e.add_to_group("enemies")
			e.global_position = p.global_position + off
			main.world.add_child(e)


## Remove the measured weapon + every spawned node it left in the world, and clear any
## residual burn/slow timers, so nothing bleeds into the next cell's measurement.
func _dmg_clear() -> void:
	if _dmg_w != null:
		_dmg_p.weapons.erase(_dmg_w)
		_dmg_w.queue_free()
		_dmg_w = null
	for c in main.world.get_children():
		if c is Player or c.is_in_group("enemies"):
			continue
		c.queue_free()                         # projectiles, mines, wells, puddles, turrets, fx
	for e in get_tree().get_nodes_in_group("enemies"):
		e.burn_timer = 0.0
		e.burn_dps = 0.0
		e.slow_timer = 0.0
