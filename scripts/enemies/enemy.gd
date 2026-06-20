class_name Enemy
extends CharacterBody2D
## Chases the nearest living player; deals contact damage. Stats are set by
## main.gd before add_child. On clients (`puppet`) there is no AI or real HP —
## position comes from network state and take_hit is cosmetic only.

signal killed(enemy: Enemy)

# damage types (weapons tag their hits; enemies may be immune to one)
const DMG_PHYS := 0
const DMG_FIRE := 1
const DMG_ICE := 2
const DMG_ENERGY := 3

# Newborns ease up to full speed over their first SPAWN_RAMP_TIME seconds (ease-in
# curve, so they accelerate) — gives players a beat to react to a fresh spawn.
const SPAWN_RAMP_TIME := 2.0
const SPAWN_RAMP_FLOOR := 0.15   # speed multiplier at the instant of spawn

# move_mode 4 (flee, Interceptor): wanders until a player comes within this range
const FLEE_RANGE := 220.0

# Soft separation: how hard overlapping neighbors push each other apart, as a
# fraction of the enemy's own move speed. NOT physics collision — this is a
# boids-style steering force over the shared per-frame grid, so the swarm spreads
# out instead of stacking on one point without the O(n^2) contact-solver cost.
const SEPARATION_STRENGTH := 0.9

# Heavy blast push (Cluster Warhead): a forced displacement, separate from the
# normal knockback/apply_push impulse (which is capped at 280 px/s — too short
# a leash for a "heavy shove" to read as heavy). Speed is fixed; how FAR it
# travels is the tunable (apply_blast_push's `distance` param).
const BLAST_PUSH_SPEED := 480.0

var age := 0.0   # seconds alive (host sim only); drives the spawn speed ramp
var hp := 2.0
var speed := 90.0
var radius := 12.0
var dmg := 1
var xp_value := 1
var elite := false
var type_id := 0   # network id of this (class, tier); see EnemySpawner.build_type_registry
var tier := 0
var resist := 0.0       # Warden: fraction of every hit shrugged off (0..1)
var dmg_affinity := DamageAffinity.new()  # per-DMG_*-type weak/strong/immune multipliers
var immune_type := -1   # bookkeeping for immune_cycle rotation + the outer aura draw —
                         # which DMG_* type is currently the (fully-blocked) "immune" slot
var pull_immune := false # ignores gravity-well yank (tanks/wardens/elites)
var cc_immune := false  # Bouncer/shards: immune to slow + knockback (can't be interrupted)
var knockback_immune := false  # bosses/tier-3: immune to knockback push (but still slowable, unlike cc_immune)
var bullet := false     # shard bullet: indestructible (no group, no collision, take_hit no-op)
var burst_count := 0    # Burster: enemy bullets sprayed on death (host)
var shield_cycle := 0.0 # Sentinel: seconds between shield phases (0 = none)
var shield_time := 0.0  # how long each shield phase lasts
var shield_timer := 0.0 # counts down within the current phase
var shielded := false
# movement: 0 chase, 1 wander (random), 2 bounce (straight, reflects off walls), 3 straight+expire
var move_mode := 0
var phase := false      # no collision with other bodies (passes through)
var life := -1.0        # >0: despawns after this many seconds (shards)
var shape := "circle"   # body silhouette: circle/triangle/square/diamond/hex/star
var heading := Vector2.RIGHT  # facing/travel direction for bounce/straight/triangle draw
var wander_timer := 0.0
var arena := Rect2(-1500, -1500, 3000, 3000)
var color := Color(0.85, 0.3, 0.35)
# caster behavior — keeps distance and telegraphs ground strikes
# cast_pattern: 0 = single strike at the target (Bombardier),
#               1 = a line of strikes ahead of the target's movement (Diviner)
var caster := false
var cast_pattern := 0
var cast_radius := 95.0
var cast_damage := 2
var cast_effect := 0    # 0 = damage strike, 1 = Disruptor (slows + dash-locks you)
var cast_timer := 2.5
var cast_cooldown := 3.0
var keep_dist := 300.0
# boss mechanics — independent of `caster` so a boss can chase normally and
# still periodically unleash a map-wide/pattern attack via cast_telegraph.
var boss := false
var max_hp := 0.0
# slam_pattern: -1 = none, 3 = checkerboard grid centered on self, 4 = a single
# massive, slow-telegraphed strike at the target (see slam_warn).
var slam_pattern := -1
var slam_radius := 100.0
var slam_damage := 2
var slam_cooldown := 5.0
var slam_timer := 0.0
var slam_warn := -1.0  # pattern 4: telegraph warn time (-1 = TELEGRAPH_WARN default)
var enrage_resist := 0.0  # extra resist as hp drops toward 0 (on top of `resist`)
var immune_cycle := 0.0   # seconds between immune_type rotations (0 = off)
var immune_pool: Array = []
var immune_timer := 0.0
var summon_cls := ""      # periodically calls in reinforcements of this class
var summon_count := 0
var summon_cooldown := 0.0
var summon_timer := 0.0
var summon_tier := -1     # -1 = normal class_tier roll, >=0 = always this tier
# Interceptor: periodically casts a jamming field via main.cast_intercept_zone.
# icast_pattern: 4 = on itself (Jammer, has down time between casts), 1 = random
# spot nearby (sized by THREAT), 2 = lingering fields on N random enemies,
# 3 = a single long rectangular field across the arena (random angle)
var icast_pattern := 0
var icast_radius := 0.0
var icast_life := 1.0
var icast_count := 0
var icast_cooldown := 1.0
var icast_timer := 0.0
var flash := 0.0
var knockback := Vector2.ZERO
var slow_timer := 0.0
var slow_mult := 1.0
var freeze_timer := 0.0  # >0: movement fully halted (Glacial Mine) — distinct from slow_mult, no floor
var blast_push_dist := 0.0  # remaining distance to travel (Cluster Warhead's heavy shove)
var blast_push_dir := Vector2.ZERO
var burn_dps := 0.0
var burn_timer := 0.0
var burn_tick := 0.0
var burn_source_pid: int = -1
var afflicts := AfflictTracker.new()  # named, timed debuffs (Purgatory mark, etc — see AfflictTracker)

var main_ref: Node  # set by main.gd (host); null on puppets
var puppet := false
var net_id := 0
var net_target := Vector2.ZERO
var _interp := NetInterp.new()  # time-based snapshot interp (used when GameSettings.net_interpolation)


func _ready() -> void:
	# bullets aren't in the "enemies" group (weapons can't target or hit them) and
	# have no collision at all — they only deal contact damage via the distance check
	if not bullet:
		add_to_group("enemies")
	collision_layer = 0 if bullet else 2
	# enemies don't physically collide with each other: 220 mutually-colliding
	# CharacterBody2D bodies was an O(n^2) contact-solver cost. Projectile hits use
	# collision_layer 2 + distance checks, and contact damage is distance-based, so
	# nothing else needs the mask. Overlap is instead avoided with a cheap boids-style
	# separation steering force (see _separation) over the shared per-frame grid.
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	cs.shape = circle
	# Deferred: death-spawned enemies (burster shards, splitter, boss summon) are
	# added from inside a physics callback (a projectile-hit kill), where
	# configuring a collision shape mid-flush throws "can't change state while
	# flushing queries". Enemies have collision_mask=0 so the shape is only for
	# projectile hit-detection — being live ~1 frame later is harmless.
	add_child.call_deferred(cs)
	net_target = global_position


var _last_sig := -1  # gate queue_redraw: only re-record _draw when the look changes


func _physics_process(delta: float) -> void:
	flash = maxf(flash - delta, 0.0)
	slow_timer = maxf(slow_timer - delta, 0.0)
	freeze_timer = maxf(freeze_timer - delta, 0.0)
	afflicts.tick(delta)
	if shield_cycle > 0.0:  # Sentinel: phase the shield on and off
		shield_timer -= delta
		if shield_timer <= 0.0:
			shielded = not shielded
			shield_timer = shield_time if shielded else shield_cycle
	# Only re-record the draw when appearance changes; a plain mover keeps its
	# cached _draw (the renderer applies the node transform regardless). This is
	# the big late-game saver — most of the swarm is idle-looking circles.
	var sig := _appearance_sig()
	if burn_timer > 0.0 or freeze_timer > 0.0 or not afflicts.is_empty() or sig != _last_sig:  # burn embers / freeze shimmer / afflict wisps animate continuously
		_last_sig = sig
		queue_redraw()
	if puppet:
		var m := Main.instance
		if m != null and m.settings != null and m.settings.net_interpolation:
			global_position = _interp.sample(Time.get_ticks_msec(), NetInterp.ENEMY_DELAY_MS)
		else:
			global_position = global_position.lerp(net_target, minf(10.0 * delta, 1.0))
		return
	if main_ref == null:
		return
	if main_ref.debug_freeze_enemies:
		return
	var target: Node2D = main_ref.nearest_alive_player(global_position)
	var spd := 0.0 if freeze_timer > 0.0 else speed * (slow_mult if slow_timer > 0.0 else 1.0)
	if not bullet and age < SPAWN_RAMP_TIME:  # newborns accelerate up to full speed
		age += delta
		var t := clampf(age / SPAWN_RAMP_TIME, 0.0, 1.0)
		spd *= lerpf(SPAWN_RAMP_FLOOR, 1.0, t * t)  # t² = ease-in (slow start, speeds up)
	if life > 0.0:
		life -= delta
		if life <= 0.0:
			# Timed despawn (shards): no `killed` signal, so erase the bookkeeping
			# entry ourselves — otherwise enemies_by_id keeps a stale reference
			# until the next network-sync pass notices it's invalid.
			main_ref.enemies_by_id.erase(net_id)
			queue_free()
			return
	var manual := false
	if caster and target != null:
		# hover near keep_dist and lob telegraphed strikes
		var to: Vector2 = target.global_position - global_position
		var dist := to.length()
		var dir := to.normalized()
		var move := dir
		if dist < keep_dist - 40.0:
			move = -dir
		elif dist <= keep_dist + 40.0:
			move = dir.orthogonal()  # strafe when in the sweet spot
		velocity = move * spd + knockback
		cast_timer -= delta
		if cast_timer <= 0.0:
			cast_timer = cast_cooldown + randf_range(1.0, 4.0)
			if cast_pattern == 1:
				# Diviner: paint a line of strikes out from the target along a random angle
				var d := Vector2.from_angle(randf() * TAU)
				for k in 3:
					var pp := target.global_position + d * (70.0 + k * 95.0)
					main_ref.cast_telegraph(pp, cast_radius, cast_damage, cast_effect)
			elif cast_pattern == 2:
				# Oracle: a ring of strikes around the target — escape through a gap
				var base := randf() * TAU
				for k in 6:
					var pp := target.global_position + Vector2.from_angle(base + TAU * k / 6.0) * 115.0
					main_ref.cast_telegraph(pp, cast_radius, cast_damage, cast_effect)
			else:
				# Bomber / Disruptor (pattern 0): always somewhat random, more so over time.
				# There's a jitter floor so it's never trivially dodgeable.
				var chaos := clampf(0.35 + main_ref.spawner.difficulty / 14.0, 0.0, 1.0)
				var lead: Vector2 = target.velocity * randf_range(0.4, 1.0 + chaos)
				var jitter := Vector2.from_angle(randf() * TAU) * (70.0 * chaos + 30.0)
				main_ref.cast_telegraph(target.global_position + lead + jitter, cast_radius, cast_damage, cast_effect)
				# a second, scattered strike (all pattern-0 casters, incl. debuffers)
				if chaos > 0.4:
					var off := Vector2.from_angle(randf() * TAU) * (90.0 * chaos + 40.0)
					main_ref.cast_telegraph(target.global_position + off, cast_radius, cast_damage, cast_effect)
	elif move_mode == 2 or move_mode == 3:  # bounce / straight (phases, moved manually)
		manual = true
		global_position += heading * spd * delta
		if move_mode == 2:  # reflect off the arena walls
			if global_position.x <= arena.position.x + radius or global_position.x >= arena.end.x - radius:
				heading.x = -heading.x
			if global_position.y <= arena.position.y + radius or global_position.y >= arena.end.y - radius:
				heading.y = -heading.y
			global_position = global_position.clamp(arena.position + Vector2(radius, radius), arena.end - Vector2(radius, radius))
	elif move_mode == 1:  # wander randomly, ignoring the player
		wander_timer -= delta
		if wander_timer <= 0.0:
			wander_timer = randf_range(0.6, 1.4)
			heading = Vector2.from_angle(randf() * TAU)
		velocity = heading * spd + knockback
	elif move_mode == 4:  # flee: Interceptor wanders until a player gets close, then runs — stays in the arena
		if target != null and global_position.distance_to(target.global_position) < FLEE_RANGE:
			velocity = (global_position - target.global_position).normalized() * spd + knockback
		else:
			wander_timer -= delta
			if wander_timer <= 0.0:
				wander_timer = randf_range(0.6, 1.4)
				heading = Vector2.from_angle(randf() * TAU)
			velocity = heading * spd + knockback
		# don't flee through the arena walls — kill the outward component near an edge
		# (the other axis still lets it slide along the wall)
		if global_position.x <= arena.position.x + radius and velocity.x < 0.0:
			velocity.x = 0.0
		elif global_position.x >= arena.end.x - radius and velocity.x > 0.0:
			velocity.x = 0.0
		if global_position.y <= arena.position.y + radius and velocity.y < 0.0:
			velocity.y = 0.0
		elif global_position.y >= arena.end.y - radius and velocity.y > 0.0:
			velocity.y = 0.0
	elif target != null:
		velocity = (target.global_position - global_position).normalized() * spd + knockback
	else:
		velocity = knockback
	# Soft separation: nudge away from overlapping neighbors so the swarm spreads
	# out rather than stacking on one point. Skipped for manual movers (bounce/
	# straight shards phase through) and for immovable enemies (bosses/tier-3),
	# which still part the swarm around them since they show up in others' queries.
	if not manual and not knockback_immune and not cc_immune:
		velocity += _separation() * spd * SEPARATION_STRENGTH
	knockback = knockback.move_toward(Vector2.ZERO, 600.0 * delta)
	if not manual:
		move_and_slide()
		if velocity.length() > 1.0:
			heading = velocity.normalized()
	if blast_push_dist > 0.0:
		var step: float = minf(BLAST_PUSH_SPEED * delta, blast_push_dist)
		global_position += blast_push_dir * step
		blast_push_dist -= step
	# Push/pull effects (knockback, gravity wells, the blast push above) must never
	# let an enemy leave the arena — clamp every mover, manual or physics-driven.
	global_position = global_position.clamp(arena.position + Vector2(radius, radius), arena.end - Vector2(radius, radius))
	if target != null \
			and global_position.distance_to(target.global_position) <= radius + Player.HURT_RADIUS:
		target.take_damage(dmg)
	# boss mechanics (host-authoritative): periodic map-wide/pattern slam,
	# rotating elemental immunity, and called-in reinforcements.
	if slam_pattern >= 0:
		slam_timer -= delta
		if slam_timer <= 0.0:
			slam_timer = slam_cooldown
			_do_slam()
	if immune_cycle > 0.0:
		immune_timer -= delta
		if immune_timer <= 0.0:
			immune_timer = immune_cycle
			var idx := immune_pool.find(immune_type)
			dmg_affinity.clear(immune_type)  # revert the outgoing slot to normal
			immune_type = immune_pool[(idx + 1) % immune_pool.size()]
			dmg_affinity.set_mult(immune_type, 0.0)
	if summon_cooldown > 0.0:
		summon_timer -= delta
		if summon_timer <= 0.0:
			summon_timer = summon_cooldown
			for i in summon_count:
				main_ref.spawner.spawn_enemy(summon_cls, summon_tier)
	# Interceptor T1-3: periodically cast a jamming field (destroys player
	# projectiles) via main.cast_intercept_zone — see EnemyGrid.in_interceptor_zone.
	if icast_pattern > 0:
		icast_timer -= delta
		if icast_timer <= 0.0:
			icast_timer = icast_cooldown
			match icast_pattern:
				4:  # T0 Jammer: re-cast the field on itself — has down time between casts
					main_ref.cast_intercept_zone(global_position, icast_radius, icast_life)
				1:  # a field dropped at a random spot nearby, sized by current THREAT
					var r: float = icast_radius * (1.0 + main_ref.spawner.diff() / 40.0)
					var p := global_position + Vector2.from_angle(randf() * TAU) * randf_range(80.0, 260.0)
					main_ref.cast_intercept_zone(p, r, icast_life)
				2:  # lingering field(s) on a handful of random live enemies — no
					# type preference, so it's unpredictable which one drags the
					# field around; the radius is bigger to compensate for not
					# being able to target reliably.
					var others: Array[Enemy] = []
					for e in EnemyGrid.all():
						if e != self:
							others.append(e)
					others.shuffle()
					for i in mini(icast_count, others.size()):
						main_ref.cast_intercept_zone(others[i].global_position, icast_radius, icast_life)
				3:  # ONE long rectangular field across the arena, random angle —
					# a single big no-fire lane instead of a chain of circles.
					main_ref.cast_intercept_line(global_position, icast_radius, icast_life)
	# burn DoT (host-authoritative) — Duration extends it, Power feeds its dps.
	# Re-igniting an active burn stacks onto it: hotter (dps) AND longer (time).
	if burn_timer > 0.0:
		if not afflicts.has("purgatory"):  # Purgatory mark: an active burn can't tick down while marked
			burn_timer -= delta
		burn_tick -= delta
		if burn_tick <= 0.0:
			burn_tick = 0.3
			var bamount := burn_dps * 0.3
			if main_ref != null and burn_source_pid >= 0:
				main_ref.add_burn_damage(burn_source_pid, minf(bamount, maxf(hp, 0.0)))
			take_hit(bamount, null, DMG_FIRE)  # may free self; nothing runs after


func take_hit(amount: float, from_pos: Variant = null, dtype: int = DMG_PHYS, source_pid: int = -1) -> void:
	if bullet:
		return  # shard bullets can't be destroyed — dodge them
	if shielded and not puppet:
		flash = 0.06  # pings off the shield — no damage
		return
	# base dmg_affinity (static, config-set) layered with any active afflict's own
	# per-type modifier (e.g. the Purgatory mark afflict applies to every DMG_* at once)
	var type_mult := dmg_affinity.get_mult(dtype) * afflicts.mult(dtype)
	if type_mult <= 0.0:
		flash = 0.06  # pings off this type's immunity — no damage
		return
	amount *= type_mult  # weak (>1) bonus or strong/resist (<1) reduction, before armor
	var eff_resist := resist
	if enrage_resist > 0.0 and max_hp > 0.0:  # enrage: tougher the lower its hp gets
		eff_resist = clampf(resist + enrage_resist * (1.0 - hp / max_hp), 0.0, 0.9)
	if eff_resist > 0.0:  # Warden armor / enrage reduces every hit (shown + applied consistently)
		amount *= 1.0 - eff_resist
	if puppet:
		# cosmetic only: real damage happens on the host
		flash = 0.12
		if amount >= 1.0 or randf() < 0.35:
			_spawn_number(amount)
		return
	if hp <= 0.0:
		return
	if source_pid >= 0 and main_ref != null:  # scoreboard: credit the dealer
		main_ref.add_damage(source_pid, minf(amount, hp))
	hp -= amount
	if main_ref != null and main_ref.debug_immortal_enemies:
		hp = max_hp
	flash = 0.12
	if from_pos != null and not cc_immune:  # can't be knocked back if interrupt-immune
		apply_push(from_pos, 130.0)

	# throttle numbers for rapid-tick weapons (flame, venom, laser)
	if amount >= 1.0 or randf() < 0.35:
		_spawn_number(amount)

	if hp <= 0.0:
		var pop := RingFx.new()
		pop.position = global_position
		pop.radius = radius * 0.5
		pop.max_radius = radius * 2.0
		pop.life = 0.25
		pop.color = color
		get_parent().add_child(pop)
		Sfx.play("kill", global_position, -6.0)
		killed.emit(self)
		queue_free()


func _spawn_number(amount: float) -> void:
	var ft := FloatText.new()
	ft.text = str(maxi(int(round(amount)), 1))
	ft.position = global_position + Vector2(randf_range(-10.0, 10.0), -radius - 6.0)
	get_parent().add_child(ft)


func apply_slow(mult: float, duration: float) -> void:
	if cc_immune:  # interrupt-immune enemies can't be slowed
		return
	# Central slow buff: every slow source funnels through here, so deepen the incoming
	# speed factor (mult, <1) by SLOW_POTENCY and clamp to SLOW_FLOOR_MULT. The 0.5 base
	# frost slow becomes 0.2 speed (an 80% slow) — frost/freeze really bites. Bosses/tier-3
	# are included (still slowable); only cc_immune enemies are exempt (returned above).
	# Purgatory mark: doubles the potency, so a slow applied while marked bites twice as hard.
	var potency := GameConfig.SLOW_POTENCY * (2.0 if afflicts.has("purgatory") else 1.0)
	var deep := 1.0 - (1.0 - mult) * potency
	slow_mult = maxf(deep, GameConfig.SLOW_FLOOR_MULT)
	slow_timer = maxf(slow_timer, duration)


## Complete movement halt (Glacial Mine) — unlike apply_slow, there is no floor: speed
## goes to zero for the duration. cc_immune (e.g. bouncer) is exempt like slow/push;
## bosses are also exempt outright — a full stop would trivialize boss fights.
func apply_freeze(duration: float) -> void:
	if cc_immune or boss:
		return
	freeze_timer = maxf(freeze_timer, duration)


## Knockback impulse away from from_pos. Used both by take_hit's per-hit
## knockback and by nova-family blasts that add an extra "shockwave" push.
func apply_push(from_pos: Vector2, strength: float) -> void:
	if cc_immune or knockback_immune:  # interrupt-immune or knockback-immune enemies can't be pushed
		return
	var kbr := 0.3 if radius >= 20.0 else 1.0
	knockback += (global_position - from_pos).normalized() * strength * kbr
	knockback = knockback.limit_length(280.0)


## A heavy forced shove away from from_pos, covering `distance` px at a fixed
## speed (BLAST_PUSH_SPEED) — separate from apply_push's capped knockback impulse,
## so a "heavy push" effect (Cluster Warhead) can actually read as heavy. Same
## immunity gate as apply_push. Re-triggering keeps the longer of the two distances.
func apply_blast_push(from_pos: Vector2, distance: float) -> void:
	if cc_immune or knockback_immune:
		return
	blast_push_dir = (global_position - from_pos).normalized()
	blast_push_dist = maxf(blast_push_dist, distance)


## Boids-style separation steering: a unit-capped push away from every neighbor
## whose body overlaps ours. Uses the shared per-frame grid (EnemyGrid.near with
## our own radius — the documented contract for a `dist <= radius + e.radius`
## check), so it's O(local) and reuses the index weapons already rebuild. Falloff
## is linear (0 at first touch, 1 at full overlap) so contact stays gentle.
func _separation() -> Vector2:
	var push := Vector2.ZERO
	for n in EnemyGrid.near(global_position, radius):
		if n == self:
			continue
		var combined := radius + n.radius
		var d := global_position - n.global_position
		var dist := d.length()
		if dist >= combined:
			continue
		if dist > 0.001:
			push += d / dist * (1.0 - dist / combined)
		else:  # exactly stacked — shove along a per-enemy fixed angle to unstick
			push += Vector2.from_angle(float(get_instance_id() % 360))
	return push.limit_length(1.0)


## Boss attack: map-wide/pattern telegraphs via main.cast_telegraph, forcing
## the player to actually move rather than just tank the hits.
func _do_slam() -> void:
	match slam_pattern:
		3:  # checkerboard grid centered on self — clears safe lanes to dodge into.
			# ignore_cap=true: a 13-strike grid would otherwise get silently
			# truncated by MAX_TELEGRAPHS (or blocked entirely if casters already
			# filled it) — the boss slam must always land in full.
			var cell := slam_radius * 1.6
			for gx in range(-2, 3):
				for gy in range(-2, 3):
					if (gx + gy) % 2 != 0:
						continue
					var pp := global_position + Vector2(gx, gy) * cell
					main_ref.cast_telegraph(pp, slam_radius, slam_damage, 0, -1.0, true)
		4:  # one massive, slow-telegraphed strike near the target — a long wind-up
			# (slam_warn) forces a real reposition. Jitter within slam_radius keeps
			# the exact landing spot uncertain so perfect pre-positioning doesn't work.
			var target: Node2D = main_ref.nearest_alive_player(global_position)
			if target == null:
				return
			var jitter := Vector2.from_angle(randf() * TAU) * randf_range(0.0, slam_radius * 0.8)
			main_ref.cast_telegraph(target.global_position + jitter, slam_radius, slam_damage, 0, slam_warn, true)
		5:  # ring of small explosions centered on the boss — escape by stepping toward
			# or away from the boss before it lands. Ring radius and phase are randomised
			# so the safe gap isn't always at the same spot relative to the player.
			var ring_target: Node2D = main_ref.nearest_alive_player(global_position)
			if ring_target == null:
				return
			var ring_r := global_position.distance_to(ring_target.global_position)
			ring_r += randf_range(-slam_radius * 0.5, slam_radius * 0.9)  # variance: safe zone shifts
			ring_r = maxf(ring_r, slam_radius * 2.0)  # never collapse the ring onto the boss
			var step := slam_radius * 1.5
			var count := clampi(int(TAU * ring_r / step), 8, 20)
			var phase := randf() * TAU  # random rotation so gaps don't repeat at the same angles
			for k in count:
				var pp := global_position + Vector2.from_angle(phase + TAU * k / count) * ring_r
				main_ref.cast_telegraph(pp, slam_radius, slam_damage, 0, -1.0, true)


func apply_burn(dps: float, duration: float, stack_mult: float = 1.0, source_pid: int = -1) -> void:
	# stack onto an active burn — both the heat (dps) and the time left — rather
	# than just refreshing a single value, so repeated ignites compound.
	# stack_mult > 1 lets a source (Flame Cone's signature) pile on faster.
	if source_pid >= 0:
		burn_source_pid = source_pid
	if burn_timer > 0.0:
		burn_dps += dps * stack_mult
		burn_timer = duration * stack_mult
	else:
		burn_dps = dps
		burn_timer = duration


## Purgatory mark: while active, this enemy takes extra damage from every source
## (take_hit) — the base bonus (AfflictConfig.DEFS.purgatory.affinity, +20% by
## default) deepens with stat_mult (Power), any slow applied to it bites twice as
## hard (apply_slow), and an active burn's remaining time stops ticking down (it
## can't fade out while marked). Not gated on cc_immune -- it's a damage debuff,
## not crowd control. Built on AfflictTracker: a weaker/shorter mark from another
## source can't cut a longer one short (see AfflictTracker.apply).
func apply_vuln(stat_mult: float, duration: float) -> void:
	var mods := AfflictConfig.deepened("purgatory", stat_mult)
	afflicts.apply("purgatory", duration, mods, AfflictConfig.DEFS.purgatory.color)


## Hover: while active, this enemy is lifted clear of ground-level hazards — it
## ignores lingering puddle effects (VenomPuddle: damage/burn/freeze-slow) entirely,
## as if it were floating above them. No stat multiplier (AfflictConfig.DEFS.hover.affinity
## is empty); ground effects gate on afflicts.has("hover") directly instead.
func apply_hover(duration: float) -> void:
	afflicts.apply("hover", duration, {}, AfflictConfig.DEFS.hover.color)


## A cheap discrete signature of the enemy's current appearance. _physics_process
## only re-records the draw when this changes (or burn is animating), so idle
## movers stop re-running _draw every frame. Heading only matters for directional
## silhouettes; circles (the common case) are rotation-invariant.
func _appearance_sig() -> int:
	var s := 0
	if flash > 0.0: s |= 1
	if slow_timer > 0.0: s |= 2
	if burn_timer > 0.0: s |= 4
	if shielded: s |= 8
	if freeze_timer > 0.0: s |= 16
	if afflicts.has("purgatory"): s |= 32
	if shape == "triangle" or shape == "diamond" or shape == "square" or shape == "hex" or shape == "star":
		s |= int((heading.angle() + PI) * 6.0) << 4  # ~9.5-degree facing buckets
	return s


## Enemies sit in a slightly darker, less-saturated band so the bright,
## fully-saturated player reads clearly even inside a dense swarm. Status tints
## (slow/burn/flash) and the ring overlays below apply on top and stay vivid.
func _muted(base: Color) -> Color:
	return Color.from_hsv(base.h, base.s * 0.8, base.v * 0.9, base.a)


func _draw() -> void:
	if afflicts.has("hover"):  # purely cosmetic float — global_position (and the
		# CollisionShape2D, which sits at local origin) never move, so the hitbox
		# is unaffected; only the drawn silhouette bobs. Per-instance phase offset
		# keeps a field of hovering enemies from bobbing in unison.
		var bob_t := Time.get_ticks_msec() * 0.001 + (get_instance_id() % 100) * 0.07
		draw_set_transform(Vector2(0.0, sin(bob_t * 2.2) * 4.0))
	var c := _muted(color)
	if slow_timer > 0.0:
		c = c.lerp(Color(0.5, 0.75, 1.0), 0.45)
	if freeze_timer > 0.0:  # solid ice — reads stronger than the slow tint
		c = c.lerp(Color(0.75, 0.92, 1.0), 0.75)
	if burn_timer > 0.0:
		# bright yellow-white, not orange: enemy bodies now sit in the warm band, so an
		# orange burn tint would vanish on red/orange enemies — this still pops on them.
		c = c.lerp(Color(1.0, 0.8, 0.3), 0.55)
	if afflicts.has("purgatory"):  # purgatory mark: a sickly violet pall over the body
		c = c.lerp(Color(0.55, 0.2, 0.7), 0.4)
	_draw_body(Color.WHITE if flash > 0.0 else c)
	if burn_timer > 0.0:  # flickering embers — driven by global time, no per-enemy state
		var t := Time.get_ticks_msec() * 0.001 + (get_instance_id() % 100) * 0.07
		for i in 2:
			var a := t * 9.0 + TAU * i / 2.0
			var p := Vector2.from_angle(a) * radius * 0.5 + Vector2(0.0, -radius * 0.4)
			var s := 1.6 + 1.3 * (0.5 + 0.5 * sin(t * 14.0 + i * 3.0))
			draw_circle(p, s, Color(1.0, 0.6, 0.15, 0.85))
	if afflicts.has("purgatory"):  # purgatory mark: a slow-pulsing violet aura with drifting spirit motes
		var vt := Time.get_ticks_msec() * 0.001 + (get_instance_id() % 100) * 0.05
		var pulse := 0.5 + 0.5 * sin(vt * 3.0)
		draw_arc(Vector2.ZERO, radius + 5.0, 0.0, TAU, 22, Color(0.6, 0.25, 0.75, 0.35 + 0.25 * pulse), 2.0)
		for i in 3:
			var va := vt * 1.4 + TAU * i / 3.0
			var vp := Vector2.from_angle(va) * (radius + 7.0)
			draw_circle(vp, 1.8, Color(0.8, 0.55, 0.95, 0.8))
	if elite:
		draw_arc(Vector2.ZERO, radius + 4.0, 0.0, TAU, 24, Color(1.0, 0.85, 0.3), 3.0)
	if boss:  # boss: an outer crimson ring of menace
		draw_arc(Vector2.ZERO, radius + 9.0, 0.0, TAU, 28, Color(1.0, 0.15, 0.15, 0.85), 4.0)
	if caster:  # bombardier: a targeting reticle
		draw_arc(Vector2.ZERO, radius + 5.0, 0.0, TAU, 20, Color(1.0, 0.4, 0.3), 2.0)
		draw_line(Vector2(-radius - 8.0, 0.0), Vector2(radius + 8.0, 0.0), Color(1.0, 0.4, 0.3), 1.5)
		draw_line(Vector2(0.0, -radius - 8.0), Vector2(0.0, radius + 8.0), Color(1.0, 0.4, 0.3), 1.5)
	if resist > 0.0:  # warden: a steel shield ring
		draw_arc(Vector2.ZERO, radius - 3.0, 0.0, TAU, 20, Color(0.85, 0.9, 1.0), 3.0)
	if burst_count > 0:  # burster: inner cells hinting it will spit bullets
		for i in 3:
			draw_circle(Vector2.from_angle(TAU * i / 3.0) * radius * 0.4, radius * 0.22, color.darkened(0.3))
	if immune_type >= 0:  # elemental: a colored aura of its immune element
		draw_arc(Vector2.ZERO, radius + 3.0, 0.0, TAU, 24, _elem_color(immune_type) * Color(1, 1, 1, 0.8), 2.0)
	# any other type-matchups (an enemy can be weak/strong against several at once): a
	# thin inner ring per weak type, a subtler one per strong/resist type — distinct from
	# the outer solid ring above, which is reserved for full immunity.
	for t in dmg_affinity.mults:
		if t == immune_type:
			continue
		var m: float = dmg_affinity.mults[t]
		if m > 1.0:
			draw_arc(Vector2.ZERO, radius - 4.0, 0.0, TAU, 16, _elem_color(t) * Color(1, 1, 1, 0.6), 1.5)
		elif m > 0.0:
			draw_arc(Vector2.ZERO, radius - 1.0, 0.0, TAU, 20, _elem_color(t) * Color(1, 1, 1, 0.35), 1.0)
	# generic afflict ring: any active affliction without a bespoke draw of its own
	# (Purgatory mark draws its own pall + motes above and is skipped here) shows
	# as a dashed ring in its own color — so new afflicts get a UI cue for free.
	for id in afflicts.active:
		if id == "purgatory":
			continue
		var a: AfflictTracker.Affliction = afflicts.active[id]
		var seg := Time.get_ticks_msec() % 1000 < 500
		draw_arc(Vector2.ZERO, radius + 7.0, 0.0, PI if seg else TAU, 14, a.color, 2.0)
	if shielded:  # sentinel: an impenetrable bubble — wait it out
		draw_circle(Vector2.ZERO, radius + 6.0, Color(0.5, 0.8, 1.0, 0.28))
		draw_arc(Vector2.ZERO, radius + 6.0, 0.0, TAU, 28, Color(0.7, 0.9, 1.0, 0.9), 2.5)
	if freeze_timer > 0.0:  # glacial mine: a cracked ice shell — fully halted, not just slowed
		draw_circle(Vector2.ZERO, radius + 5.0, Color(0.8, 0.95, 1.0, 0.35))
		draw_arc(Vector2.ZERO, radius + 5.0, 0.0, TAU, 24, Color(0.85, 0.97, 1.0, 0.95), 2.5)
		for i in 3:
			var a := TAU * i / 3.0 + 0.4
			draw_line(Vector2.ZERO, Vector2.from_angle(a) * (radius + 5.0), Color(0.9, 0.98, 1.0, 0.8), 1.5)


## Distinct silhouette per class so enemies read at a glance. Polygons point along
## `heading` so directional enemies (rushers, bouncers, shards) face where they move.
func _draw_body(col: Color) -> void:
	var n := 0
	match shape:
		"triangle":
			n = 3
		"diamond":
			n = 4
		"square":
			n = 4
		"hex":
			n = 6
		"star":
			_draw_star(col)
			return
		_:
			draw_circle(Vector2.ZERO, radius, col)
			return
	var a0 := heading.angle()
	if shape == "square":
		a0 += PI / 4.0
	var pts := PackedVector2Array()
	for i in n:
		pts.append(Vector2.from_angle(a0 + TAU * i / n) * radius)
	draw_colored_polygon(pts, col)


func _draw_star(col: Color) -> void:
	var pts := PackedVector2Array()
	var a0 := heading.angle()
	for i in 10:
		var r := radius if i % 2 == 0 else radius * 0.45
		pts.append(Vector2.from_angle(a0 + TAU * i / 10.0) * r)
	draw_colored_polygon(pts, col)


func _elem_color(t: int) -> Color:
	match t:
		DMG_FIRE:
			return Color(1.0, 0.5, 0.2)
		DMG_ICE:
			return Color(0.6, 0.85, 1.0)
		DMG_ENERGY:
			return Color(0.8, 0.7, 1.0)
	return Color(0.8, 0.8, 0.85)
