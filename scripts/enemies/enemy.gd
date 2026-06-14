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
var immune_type := -1   # Elemental: takes zero damage of this DMG_* type
var pull_immune := false # ignores gravity-well yank (tanks/wardens/elites)
var cc_immune := false  # Bouncer/shards: immune to slow + knockback (can't be interrupted)
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
var arena := Rect2(-1200, -1200, 2400, 2400)
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
# slam_pattern: -1 = none, 3 = checkerboard grid centered on self, 4 = rotating
# sweep radiating from the target (advances `slam_rot` each cast).
var slam_pattern := -1
var slam_radius := 100.0
var slam_damage := 2
var slam_cooldown := 5.0
var slam_timer := 0.0
var slam_rot := 0.0
var enrage_resist := 0.0  # extra resist as hp drops toward 0 (on top of `resist`)
var immune_cycle := 0.0   # seconds between immune_type rotations (0 = off)
var immune_pool: Array = []
var immune_timer := 0.0
var summon_cls := ""      # periodically calls in reinforcements of this class
var summon_count := 0
var summon_cooldown := 0.0
var summon_timer := 0.0
var flash := 0.0
var knockback := Vector2.ZERO
var slow_timer := 0.0
var slow_mult := 1.0
var burn_dps := 0.0
var burn_timer := 0.0
var burn_tick := 0.0

var main_ref: Node  # set by main.gd (host); null on puppets
var puppet := false
var net_id := 0
var net_target := Vector2.ZERO


func _ready() -> void:
	# bullets aren't in the "enemies" group (weapons can't target or hit them) and
	# have no collision at all — they only deal contact damage via the distance check
	if not bullet:
		add_to_group("enemies")
	collision_layer = 0 if bullet else 2
	# enemies no longer collide with each other: 220 mutually-colliding CharacterBody2D
	# bodies was an O(n^2) contact-solver cost. Projectile hits use collision_layer 2 +
	# distance checks, and contact damage is distance-based, so nothing else needs this.
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	cs.shape = circle
	add_child(cs)
	net_target = global_position


func _physics_process(delta: float) -> void:
	flash = maxf(flash - delta, 0.0)
	slow_timer = maxf(slow_timer - delta, 0.0)
	if shield_cycle > 0.0:  # Sentinel: phase the shield on and off
		shield_timer -= delta
		if shield_timer <= 0.0:
			shielded = not shielded
			shield_timer = shield_time if shielded else shield_cycle
	queue_redraw()
	if puppet:
		global_position = global_position.lerp(net_target, minf(10.0 * delta, 1.0))
		return
	if main_ref == null:
		return
	var target: Node2D = main_ref.nearest_alive_player(global_position)
	var spd := speed * (slow_mult if slow_timer > 0.0 else 1.0)
	if not bullet and age < SPAWN_RAMP_TIME:  # newborns accelerate up to full speed
		age += delta
		var t := clampf(age / SPAWN_RAMP_TIME, 0.0, 1.0)
		spd *= lerpf(SPAWN_RAMP_FLOOR, 1.0, t * t)  # t² = ease-in (slow start, speeds up)
	if life > 0.0:
		life -= delta
		if life <= 0.0:
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
			cast_timer = cast_cooldown
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
	elif target != null:
		velocity = (target.global_position - global_position).normalized() * spd + knockback
	else:
		velocity = knockback
	knockback = knockback.move_toward(Vector2.ZERO, 600.0 * delta)
	if not manual:
		move_and_slide()
		if velocity.length() > 1.0:
			heading = velocity.normalized()
	if target != null \
			and global_position.distance_to(target.global_position) <= radius + Player.RADIUS:
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
			immune_type = immune_pool[(idx + 1) % immune_pool.size()]
	if summon_cooldown > 0.0:
		summon_timer -= delta
		if summon_timer <= 0.0:
			summon_timer = summon_cooldown
			for i in summon_count:
				main_ref.spawner.spawn_enemy(summon_cls)
	# burn DoT (host-authoritative) — Duration extends it, Power feeds its dps.
	# Re-igniting an active burn stacks onto it: hotter (dps) AND longer (time).
	if burn_timer > 0.0:
		burn_timer -= delta
		burn_tick -= delta
		if burn_tick <= 0.0:
			burn_tick = 0.3
			take_hit(burn_dps * 0.3, null, DMG_FIRE)  # may free self; nothing runs after


func take_hit(amount: float, from_pos: Variant = null, dtype: int = DMG_PHYS, source_pid: int = -1) -> void:
	if bullet:
		return  # shard bullets can't be destroyed — dodge them
	if dtype == immune_type or (shielded and not puppet):
		flash = 0.06  # pings off the shield / immunity — no damage
		return
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
	flash = 0.12
	if from_pos != null and not cc_immune:  # can't be knocked back if interrupt-immune
		var kbr := 0.3 if radius >= 20.0 else 1.0
		knockback += (global_position - from_pos).normalized() * 130.0 * kbr
		knockback = knockback.limit_length(280.0)

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
	slow_mult = mult
	slow_timer = maxf(slow_timer, duration)


## Boss attack: map-wide/pattern telegraphs via main.cast_telegraph, forcing
## the player to actually move rather than just tank the hits.
func _do_slam() -> void:
	match slam_pattern:
		3:  # checkerboard grid centered on self — clears safe lanes to dodge into
			var cell := slam_radius * 1.6
			for gx in range(-2, 3):
				for gy in range(-2, 3):
					if (gx + gy) % 2 != 0:
						continue
					var pp := global_position + Vector2(gx, gy) * cell
					main_ref.cast_telegraph(pp, slam_radius, slam_damage, 0)
		4:  # rotating sweep — a line of strikes from the target that rotates each cast
			var target: Node2D = main_ref.nearest_alive_player(global_position)
			if target == null:
				return
			slam_rot += PI / 3.0  # 60° per cast — full rotation every 6 casts
			for k in 4:
				var pp := target.global_position + Vector2.from_angle(slam_rot) * (60.0 + k * 90.0)
				main_ref.cast_telegraph(pp, slam_radius, slam_damage, 0)


func apply_burn(dps: float, duration: float) -> void:
	# stack onto an active burn — both the heat (dps) and the time left — rather
	# than just refreshing a single value, so repeated ignites compound
	if burn_timer > 0.0:
		burn_dps += dps
		burn_timer += duration
	else:
		burn_dps = dps
		burn_timer = duration


func _draw() -> void:
	var c := color
	if slow_timer > 0.0:
		c = c.lerp(Color(0.5, 0.75, 1.0), 0.45)
	if burn_timer > 0.0:
		c = c.lerp(Color(1.0, 0.45, 0.1), 0.55)
	_draw_body(Color.WHITE if flash > 0.0 else c)
	if burn_timer > 0.0:  # flickering embers — driven by global time, no per-enemy state
		var t := Time.get_ticks_msec() * 0.001 + (get_instance_id() % 100) * 0.07
		for i in 2:
			var a := t * 9.0 + TAU * i / 2.0
			var p := Vector2.from_angle(a) * radius * 0.5 + Vector2(0.0, -radius * 0.4)
			var s := 1.6 + 1.3 * (0.5 + 0.5 * sin(t * 14.0 + i * 3.0))
			draw_circle(p, s, Color(1.0, 0.6, 0.15, 0.85))
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
	if shielded:  # sentinel: an impenetrable bubble — wait it out
		draw_circle(Vector2.ZERO, radius + 6.0, Color(0.5, 0.8, 1.0, 0.28))
		draw_arc(Vector2.ZERO, radius + 6.0, 0.0, TAU, 28, Color(0.7, 0.9, 1.0, 0.9), 2.5)


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
