class_name EnemySpawner
extends Node
## Host-side enemy spawning + dynamic difficulty/heat, plus the enemy type
## registry (built on host and clients alike, so puppet enemies decode
## correctly). `main` is the back-reference to the root Main node, used to
## reach the world, player list, and enemy registry — mirrors how `Net` works.

var main: Node

# --- enemy type registry: flat [{cls, tier, data}], index is the network id ---
var types := []
var type_id := {}

# --- dynamic difficulty (host-authoritative; clients read net_* via HUD sync) ---
# Split into two independent tracks:
#  - `pace`: enemy VARIETY (class_tier ceiling) + desired population. Climbs at a
#    flat rate from elapsed time alone — never accelerates, so a fast/skilled
#    party doesn't get buried under more enemy *types* than the run "should" have yet.
#  - `difficulty`: how tough each enemy is to CLEAR (hp/speed/dmg in make_enemy).
#    Climbs at the same base rate as `pace` but is accelerated by heat (clear-rate)
#    and party level — a party that's ahead of the curve fights harder monsters,
#    without the spawn variety/population also exploding.
var pace := 0.0               # host-only: time-based, never accelerated
var difficulty := 0.0
var net_difficulty := 0.0
var heat_cur := 0.0          # smoothed heat (rises fast, decays slowly)
var net_heat := 0.0          # heat received from host (clients display it)
var heat_spike := 0.0        # exponential surge when the map is nearly cleared (mid-game+)
var clear_kills := 0         # kills counted in the current 1 s window
var clear_t := 0.0
var clear_ema := 0.0         # smoothed kills/sec
var spawn_rate := 1.0        # current steady spawns/sec (from run_spawning)
var desired_pop := 18        # target alive-enemy count (grows with pace)

# --- spawn cadence state ---
var spawn_accum := 0.0
var special_accum := {}      # SPAWN_SPECIALS key -> seconds accumulated
var enemy_seq := 0

# --- boss spawns: a tough "boss" class enemy after enough total kills ---
var total_kills := 0
var boss_count := 0
var boss_next_kill := 0

# --- bouncer: a special population, separate from the normal pool/desired_pop,
# with its own (growing) cap ---
var bouncer_live := 0
var bouncer_accum := 0.0


## Flattens EnemyConfig.CLASSES into a stable, index-addressable list.
## Deterministic (dict insertion order) so host and clients agree on every
## type id.
func build_type_registry() -> void:
	types = []
	type_id = {}
	for cls in EnemyConfig.CLASSES:
		var tiers: Array = EnemyConfig.CLASSES[cls]
		for ti in tiers.size():
			type_id["%s:%d" % [cls, ti]] = types.size()
			types.append({"cls": cls, "tier": ti, "data": tiers[ti]})


func reset() -> void:
	pace = 0.0
	difficulty = 0.0
	net_difficulty = 0.0
	heat_cur = 0.0
	net_heat = 0.0
	heat_spike = 0.0
	clear_kills = 0
	clear_t = 0.0
	clear_ema = 0.0
	spawn_rate = 1.0
	desired_pop = int(GameConfig.SPAWN_DESIRED_BASE)
	spawn_accum = 0.0
	special_accum = {}
	enemy_seq = 0
	total_kills = 0
	boss_count = 0
	boss_next_kill = GameConfig.BOSS_KILL_BASE
	bouncer_live = 0
	bouncer_accum = 0.0


## Dynamic difficulty from clear rate: 0 when you're barely keeping pace with
## the spawn pressure, ramping to 1 the faster you clear beyond it. Clear the
## swarm quickly and the game pushes harder (more elites, higher tiers,
## tougher enemies). Host computes from its kill-rate EMA; clients use the
## synced value.
func heat() -> float:
	return net_heat if not main.is_host() else heat_cur


## Master difficulty: the single number every enemy stat scales from.
func diff() -> float:
	return net_difficulty if not main.is_host() else difficulty


## Early-game brake: difficulty climbs (and level-up steps land) at a fraction
## of full speed for the first ~80 s, then ramps to full. Keeps the opening gentle.
func warmup() -> float:
	return clampf(GameConfig.DIFF_WARMUP_FLOOR + main.elapsed / GameConfig.DIFF_WARMUP_SECS, GameConfig.DIFF_WARMUP_FLOOR, 1.0)


## Boss spawn trigger: a tough "boss"-class enemy after enough total kills,
## escalating to the next boss tier each time (capped at the roster size).
func add_kill() -> void:
	clear_kills += 1
	total_kills += 1
	if total_kills >= boss_next_kill and main.enemies_by_id.size() < GameConfig.ENEMY_CAP:
		spawn_boss()
		boss_count += 1
		boss_next_kill += GameConfig.BOSS_KILL_INTERVAL


func spawn_boss() -> void:
	var n: int = EnemyConfig.CLASSES["boss"].size()
	var tier := clampi(boss_count, 0, n - 1)
	spawn_enemy("boss", tier)


## Leveling up directly raises difficulty.
func add_level_difficulty() -> void:
	difficulty += GameConfig.DIFF_LEVEL_STEP * warmup()


## Host: update the clear-rate heat (smoothed, rises fast / decays slowly) and
## let it + the party level accelerate the master difficulty climb.
func update_difficulty(delta: float) -> void:
	clear_t += delta
	if clear_t >= 1.0:
		clear_ema = lerpf(clear_ema, clear_kills / clear_t, 0.5)
		clear_kills = 0
		clear_t = 0.0
	var target := clampf((clear_ema - spawn_rate) / (spawn_rate * 2.0 + 1.0), 0.0, 1.0)
	# Overwhelmed (field packed + barely clearing)? Bleed heat off fast to ease the
	# difficulty climb and give the struggling player some breathing room.
	# (Bouncers have their own population/cap and don't count here.)
	var pool_count := _pool_count()
	var overwhelmed: bool = pool_count > desired_pop * 1.4 and clear_ema < spawn_rate * 0.7
	if overwhelmed:
		target = 0.0
	# rise quickly, decay slowly (faster when overwhelmed) so heat lingers in lulls
	var rate := 0.7 if target > heat_cur else (0.35 if overwhelmed else 0.05)
	heat_cur = move_toward(heat_cur, target, rate * delta)
	# Exponential spike: if the map is nearly cleared well into the run, the
	# difficulty climb surges hard — a reward for crushing it. Gated to
	# mid-game+ so it can't trigger from an early, naturally-empty arena.
	var pop_frac: float = pool_count / maxf(float(desired_pop), 1.0)
	if main.elapsed >= GameConfig.MID_GAME_TIME and pop_frac < GameConfig.HEAT_SPIKE_POP_FRAC:
		heat_spike = minf((heat_spike + delta) * (1.0 + GameConfig.HEAT_SPIKE_GROWTH * delta), GameConfig.HEAT_SPIKE_MAX)
	else:
		heat_spike = move_toward(heat_spike, 0.0, GameConfig.HEAT_SPIKE_DECAY * delta)
	var base_climb := delta * GameConfig.DIFF_BASE * warmup()
	pace += base_climb  # variety/population: flat time-based climb, no acceleration
	difficulty += base_climb * (1.0 + heat_cur * GameConfig.DIFF_HEAT + heat_spike * GameConfig.DIFF_SPIKE + (main.level - 1) * GameConfig.DIFF_LEVEL)


# --- spawning ----------------------------------------------------------------

## Per-minute wave [intensity, pop_mult], lerped between adjacent minutes for a smooth
## peaks/valleys rhythm. Pure function of elapsed (already synced), so host & clients agree.
func _wave() -> Vector2:
	var w: Array = GameConfig.WAVES
	var tm: float = main.elapsed / 60.0
	var i := int(floor(tm))
	if i >= w.size() - 1:
		var last: Array = w[w.size() - 1]
		return Vector2(last[0], last[1])
	var f := tm - float(i)
	var a: Array = w[i]
	var b: Array = w[i + 1]
	return Vector2(lerpf(a[0], b[0], f), lerpf(a[1], b[1], f))


func wave_intensity() -> float:  # >1 = faster spawns (peak), <1 = slower (valley)
	return _wave().x


func wave_pop_mult() -> float:   # scales desired_pop; valleys thin the field for a breather
	return _wave().y


func run_spawning(delta: float) -> void:
	var heat_v := heat()
	var t := clampf(main.elapsed / 540.0, 0.0, 1.0)
	var interval: float = lerpf(GameConfig.SPAWN_INTERVAL_START, GameConfig.SPAWN_INTERVAL_END, t) / (1.0 + 0.6 * (main.peer_ids.size() - 1))
	interval /= maxf(wave_intensity(), 0.1)  # wave peak = faster spawns, valley = slower
	# keep the arena populated: if the player clears faster than enemies arrive,
	# ramp spawns to refill toward a target population. The target starts small
	# (calm opening) and grows with pace (time only — doesn't spike for a fast party).
	# (Bouncers have their own population/cap below and don't count toward this.)
	desired_pop = int(clampf((GameConfig.SPAWN_DESIRED_BASE + pace * GameConfig.SPAWN_DESIRED_PER_DIFF) * wave_pop_mult(), GameConfig.WAVE_POP_FLOOR, GameConfig.ENEMY_CAP - 20))
	if _pool_count() < desired_pop:
		interval *= GameConfig.SPAWN_REFILL_MULT
	spawn_rate = 1.0 / interval
	spawn_accum += delta
	while spawn_accum >= interval:
		spawn_accum -= interval
		if main.enemies_by_id.size() >= GameConfig.ENEMY_CAP:
			break
		spawn_enemy(_pick_pool_class())  # tier escalates with time/level/heat
	for id in EnemyConfig.SPAWN_SPECIALS:
		var s: Dictionary = EnemyConfig.SPAWN_SPECIALS[id]
		if main.elapsed <= s.unlock:
			continue
		var acc: float = special_accum.get(id, 0.0) + delta
		var int_hi: float = s.get("interval_hi", s.get("interval", 0.0))
		var int_lo: float = s.get("interval_lo", s.get("interval", 0.0))
		if acc >= lerpf(int_hi, int_lo, heat_v):
			acc = 0.0
			spawn_enemy(s.cls)
		special_accum[id] = acc
	# Bouncer: a special population, separate from the normal pool above. Once
	# unlocked it maintains its own (growing) cap independently — never counted
	# toward desired_pop/overwhelmed and never crowded out by the normal pool.
	if main.elapsed >= GameConfig.BOUNCER_UNLOCK:
		var bouncer_cap := int(GameConfig.BOUNCER_CAP_BASE + pace * GameConfig.BOUNCER_CAP_PER_PACE)
		bouncer_accum += delta
		if bouncer_accum >= GameConfig.BOUNCER_SPAWN_INTERVAL:
			bouncer_accum -= GameConfig.BOUNCER_SPAWN_INTERVAL
			if bouncer_live < bouncer_cap and main.enemies_by_id.size() < GameConfig.ENEMY_CAP:
				spawn_enemy("bouncer")  # tier escalates with pace like any other class


## Weighted random pick over every SPAWN_POOL row unlocked at the current time.
func _pick_pool_class() -> String:
	var total := 0.0
	var unlocked := []
	for row in EnemyConfig.SPAWN_POOL:
		if main.elapsed >= row.unlock:
			unlocked.append(row)
			total += row.weight
	var r := randf() * total
	for row in unlocked:
		r -= row.weight
		if r <= 0.0:
			return row.cls
	return unlocked[-1].cls


## Which tier of a class to spawn now: rises with elapsed time only (`pace`), so
## harder variants (Diviner, Behemoth, Champion…) show up on a fixed schedule —
## a party that's ahead of par doesn't get flooded with rarer variants too.
func class_tier(cls: String) -> int:
	var n: int = EnemyConfig.CLASSES[cls].size()
	if n <= 1:
		return 0
	# Pace raises the tier *ceiling*; the actual tier is sampled below it so
	# higher ranks just get MORE common while lower ranks keep spawning.
	var ceiling := clampi(int(pace / 3.0), 0, n - 1)
	if EnemyConfig.CLASSES[cls][0].get("uniform_tier", false):
		# Marked classes (casters): every unlocked tier is equally likely,
		# instead of skewing toward the ceiling — Bomber/Diviner/Oracle stay
		# evenly mixed rather than Oracle dominating late-game.
		return randi() % (ceiling + 1)
	var tier := ceiling
	while tier > 0 and randf() < 0.4:  # ~40% chance to step down each rank
		tier -= 1
	return tier


func make_enemy(cls: String, tier: int) -> Enemy:
	var d: Dictionary = EnemyConfig.CLASSES[cls][tier]
	var e := Enemy.new()
	e.type_id = type_id["%s:%d" % [cls, tier]]
	e.tier = tier
	var dl := diff()  # clear-difficulty drives hp/speed/dmg scaling (heat-accelerated)
	var party: float = 1.0 + 0.5 * (main.peer_ids.size() - 1)
	e.hp = (d.hp0 + dl * d.hpk) * party
	e.speed = d.spd + dl * d.get("spdk", 0.0)
	e.radius = d.r
	e.dmg = d.dmg + int(dl / 12.0)  # enemies hit harder as difficulty climbs
	e.xp_value = d.xp
	e.color = d.col
	e.elite = d.get("elite", false)
	e.resist = d.get("resist", 0.0)
	e.immune_type = d.get("immune", -1)
	e.pull_immune = d.get("pull_imm", false)
	e.cc_immune = d.get("cc_imm", false)
	e.bullet = d.get("bullet", false)
	e.burst_count = d.get("burst", 0)
	e.move_mode = d.get("move", 0)
	e.phase = d.get("phase", false)
	e.life = d.get("life", -1.0)
	e.shape = d.get("shape", "circle")
	e.arena = GameConfig.ARENA
	e.heading = Vector2.from_angle(randf() * TAU)  # random initial facing/travel dir
	e.shield_cycle = d.get("shield_cycle", 0.0)
	e.shield_time = d.get("shield_time", 0.0)
	if d.get("caster", false):
		e.caster = true
		e.cast_pattern = d.pattern
		e.cast_radius = d.cr
		e.cast_damage = d.cd
		e.cast_effect = d.get("effect", 0)
		e.cast_cooldown = d.get("cdt", 3.0)
		e.cast_timer = e.cast_cooldown
		e.keep_dist = d.keep
	# boss mechanics: map-wide/pattern "slam" attacks + per-tier hard-to-kill gimmicks
	e.boss = d.get("boss", false)
	e.slam_pattern = d.get("slam_pattern", -1)
	e.slam_radius = d.get("slam_radius", 100.0)
	e.slam_damage = d.get("slam_damage", 2)
	e.slam_cooldown = d.get("slam_cooldown", 5.0)
	if e.slam_pattern >= 0:
		e.slam_timer = e.slam_cooldown * 0.6  # short delay before the first slam
	e.enrage_resist = d.get("enrage_resist", 0.0)
	var immune_pool: Array = d.get("immune_pool", [])
	if immune_pool.size() > 0:
		e.immune_cycle = d.immune_cycle
		e.immune_pool = immune_pool
		e.immune_type = immune_pool[0]
		e.immune_timer = e.immune_cycle
	e.summon_cls = d.get("summon_cls", "")
	e.summon_count = d.get("summon_count", 0)
	e.summon_cooldown = d.get("summon_cooldown", 0.0)
	e.summon_timer = e.summon_cooldown
	# configured enemy-scale multiplier (difficulty is already baked into hp/speed above)
	e.hp *= main.cfg_enemy_scale
	e.speed *= lerpf(1.0, main.cfg_enemy_scale, 0.4)
	e.max_hp = e.hp
	return e


func make_enemy_by_type(tid: int) -> Enemy:
	var ty: Dictionary = types[tid]
	return make_enemy(ty.cls, ty.tier)


func spawn_enemy(cls: String, tier: int = -1) -> void:
	if tier < 0:
		tier = class_tier(cls)
	var e := make_enemy(cls, tier)
	e.main_ref = main
	e.net_id = enemy_seq
	enemy_seq += 1
	e.killed.connect(main._on_enemy_killed)
	var around: Node2D = main.nearest_alive_player(Vector2.ZERO)
	var center: Vector2 = around.global_position if around != null else Vector2.ZERO
	e.position = _enemy_spawn_pos(center)
	main.enemies_by_id[e.net_id] = e
	main.world.add_child(e)
	if cls == "bouncer":
		bouncer_live += 1


## Pick a spawn point on the [SPAWN_RING_MIN, SPAWN_RING_MAX] ring around `center`,
## clamped to the arena. Because the per-axis clamp can drag a point back toward a
## player parked near an edge/corner, we retry a few angles and reject any result
## that lands within SPAWN_SAFE_RADIUS of ANY alive player. If every try is blocked
## (player boxed into a corner), nudge the best candidate straight away from the
## nearest player so an enemy never materialises on top of someone.
func _enemy_spawn_pos(center: Vector2) -> Vector2:
	var safe_sq := GameConfig.SPAWN_SAFE_RADIUS * GameConfig.SPAWN_SAFE_RADIUS
	var best := center
	var best_d := -1.0
	for _i in 8:
		var pos := center + Vector2.from_angle(randf() * TAU) * randf_range(GameConfig.SPAWN_RING_MIN, GameConfig.SPAWN_RING_MAX)
		pos.x = clampf(pos.x, GameConfig.ARENA.position.x + 30.0, GameConfig.ARENA.end.x - 30.0)
		pos.y = clampf(pos.y, GameConfig.ARENA.position.y + 30.0, GameConfig.ARENA.end.y - 30.0)
		var near: Node2D = main.nearest_alive_player(pos)
		var nd: float = INF if near == null else pos.distance_squared_to(near.global_position)
		if nd >= safe_sq:
			return pos
		if nd > best_d:
			best_d = nd
			best = pos
	var fallback: Node2D = main.nearest_alive_player(best)
	if fallback != null:
		var away: Vector2 = best - fallback.global_position
		away = Vector2.from_angle(randf() * TAU) if away.length() < 1.0 else away.normalized()
		best = fallback.global_position + away * GameConfig.SPAWN_SAFE_RADIUS
		best.x = clampf(best.x, GameConfig.ARENA.position.x + 30.0, GameConfig.ARENA.end.x - 30.0)
		best.y = clampf(best.y, GameConfig.ARENA.position.y + 30.0, GameConfig.ARENA.end.y - 30.0)
	return best


## Live enemy count excluding the bouncer population (which has its own cap
## and never counts toward the normal pool's desired_pop/overwhelmed).
func _pool_count() -> int:
	return main.enemies_by_id.size() - bouncer_live


## A Burster's death spray: enemy "shard" bullets fired radially. Deferred because
## the death can fire inside a physics collision callback (adding bodies mid-flush).
func spawn_burst(pos: Vector2, count: int) -> void:
	if not main.playing or main.world == null:
		return
	var base := randf() * TAU
	for i in count:
		if main.enemies_by_id.size() >= GameConfig.ENEMY_CAP:
			break
		var c := make_enemy("shard", 0)
		c.main_ref = main
		c.net_id = enemy_seq
		enemy_seq += 1
		c.killed.connect(main._on_enemy_killed)
		c.heading = Vector2.from_angle(base + TAU * i / count)  # even radial spray
		c.position = pos + c.heading * 16.0
		main.enemies_by_id[c.net_id] = c
		main.world.add_child(c)
