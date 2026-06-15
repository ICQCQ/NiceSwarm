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
	for pid in main.players:
		main.players[pid].bot = true  # host drives every player as a kiting bot
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
		print("[sim] style=%s party=%d seed=%d result=%s time=%.1f diff=%.1f level=%d kills=%d ttk=%.2f" \
			% [style, main.peer_ids.size(), seed_val, ("WIN" if won else "DEAD"), elapsed_, main.spawner.diff(), level_, kills_, ttk])
		main.get_tree().quit(0)
		return true
	if Engine.time_scale > 1.0:  # NICESWARM_FF: final calibration line, then drop the clock back
		print("[ff] END won=%s min=%.1f level=%d kills=%d gems=%d" \
			% [str(won), elapsed_ / 60.0, level_, kills_, main.gems_by_id.size()])
		Engine.time_scale = 1.0
	return false


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
	print("[ff] min=%d level=%d xp_need=%d gems=%d enemies=%d diff=%.1f" \
		% [m, main.level, main._xp_needed(), main.gems_by_id.size(), main.enemies_by_id.size(), main.spawner.difficulty])
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
