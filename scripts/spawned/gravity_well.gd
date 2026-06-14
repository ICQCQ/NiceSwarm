class_name GravityWell
extends Node2D
## Vortex that drags enemies toward its center and damages them in ticks.

var radius := 160.0
var source_pid := -1  # scoreboard: which player owns this
var damage := 1.0     # per tick
var pull := 170.0     # px/s drag, scaled down per-enemy as its pull resistance builds
var life := 2.5
var detonate_damage := 0.0  # fused Singularity: collapse blast on expiry
var freeze := false         # fused Glacier: chills everything inside
var beam_spokes := 0        # fused Accretion Beam: rotating energy beams within the vortex
var beam_dmg := 0.0
var beam_len := 0.0
var beam_spin := 2.0
var chain_dmg := 0.0        # fused Storm Vortex: arcs lightning between enemies caught inside
var tick := 0.0
var spin := 0.0
var beam_angle := 0.0
var _beam_hit_cd := {}
var pull_factor := {}       # enemy id -> remaining pull grip (1 → 0 as it resists)
var _hit_enemies := {}       # enemy id -> true: base `damage` lands once per enemy, not per tick


func _ready() -> void:
	z_index = -1


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		if detonate_damage > 0.0:
			_detonate()
		queue_free()
		return
	spin += 4.0 * delta
	queue_redraw()
	tick -= delta
	var do_damage := tick <= 0.0
	if do_damage:
		tick = 0.35
	var inside: Array = []
	for e in EnemyGrid.near(global_position, radius):
		var d := global_position.distance_to(e.global_position)
		if d <= radius + e.radius:
			# gradual pull, but each enemy builds resistance — grip fades from 1 to 0
			# over ~1.7 s, so it's drawn in then released rather than held forever
			if not e.pull_immune:
				var id := e.get_instance_id()
				var f: float = pull_factor.get(id, 1.0)
				if f > 0.0:
					e.global_position = e.global_position.move_toward(global_position, pull * f * delta)
				pull_factor[id] = maxf(f - 0.6 * delta, 0.0)
			if freeze:
				e.apply_slow(0.45, 0.5)
			if damage > 0.0:
				var id := e.get_instance_id()
				if not _hit_enemies.has(id):  # base gravity damage: one instance per enemy, not per tick
					_hit_enemies[id] = true
					e.take_hit(damage, global_position, Enemy.DMG_ENERGY, source_pid)
			if do_damage:
				inside.append(e)
	if chain_dmg > 0.0 and inside.size() >= 2:
		inside.shuffle()
		var pts: Array = []
		for e in inside.slice(0, 4):
			pts.append(e.global_position)
			e.take_hit(chain_dmg, global_position, Enemy.DMG_ENERGY, source_pid)
		var fx := LightningFx.new()
		fx.points = pts
		get_parent().add_child(fx)
	if beam_spokes > 0:
		beam_angle = fmod(beam_angle + beam_spin * delta, TAU)
		var expired := []
		for k in _beam_hit_cd:
			_beam_hit_cd[k] -= delta
			if _beam_hit_cd[k] <= 0.0:
				expired.append(k)
		for k in expired:
			_beam_hit_cd.erase(k)
		for e in EnemyGrid.near(global_position, beam_len):
			if _beam_hit_cd.has(e.get_instance_id()):
				continue
			var rel: Vector2 = e.global_position - global_position
			for s in beam_spokes:
				var dir := Vector2.from_angle(beam_angle + TAU * float(s) / beam_spokes)
				var along := clampf(rel.dot(dir), 0.0, beam_len)
				if (dir * along).distance_to(rel) <= 8.0 + e.radius:
					e.take_hit(beam_dmg, global_position + dir * along, Enemy.DMG_ENERGY, source_pid)
					_beam_hit_cd[e.get_instance_id()] = 0.35
					break


func _detonate() -> void:
	var fx := RingFx.new()
	fx.position = global_position
	fx.radius = 20.0
	fx.max_radius = radius
	fx.life = 0.35
	fx.color = Color(0.8, 0.4, 1.0)
	get_parent().add_child(fx)
	Sfx.play("boom", global_position)
	for e in EnemyGrid.near(global_position, radius):
		if global_position.distance_to(e.global_position) <= radius + e.radius:
			e.take_hit(detonate_damage, global_position, Enemy.DMG_PHYS, source_pid)


func _draw() -> void:
	var a := clampf(life / 0.5, 0.0, 1.0)  # quick fade-out at the end
	for i in 3:
		var r := radius * (0.35 + 0.3 * i)
		var start := spin * (1.0 + 0.4 * i)
		draw_arc(Vector2.ZERO, r, start, start + TAU * 0.7, 24,
			Color(0.7, 0.4, 1.0, (0.5 - 0.12 * i) * a), 3.0)
	draw_circle(Vector2.ZERO, 10.0, Color(0.5, 0.25, 0.8, 0.8 * a))
	if beam_spokes > 0:
		for s in beam_spokes:
			var dir := Vector2.from_angle(beam_angle + TAU * float(s) / beam_spokes)
			draw_line(Vector2.ZERO, dir * beam_len, Color(0.85, 0.5, 1.0, 0.3 * a), 7.0)
			draw_line(Vector2.ZERO, dir * beam_len, Color(1.0, 0.85, 1.0, a), 2.5)
