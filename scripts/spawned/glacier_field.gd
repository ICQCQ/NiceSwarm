class_name GlacierField
extends Node2D
## Glacier (frost+gravity): a frost vortex that drags enemies in and chills them
## continuously, while pulsing a "cold wave" through the field every
## `wave_interval` seconds. Each wave that hits an enemy stacks; the
## `freeze_wave_threshold`th wave fully freezes it (apply_freeze) and resets its
## stack. Diverges enough from the shared GravityWell (no chain/beam payloads,
## a stacking-freeze mechanic, an ice-only palette) to stand alone rather than
## bending that shared class for its 9 other consumers.

var source_pid := -1  # scoreboard: which player owns this
var source_weapon: WeaponBase
var radius := 160.0
var damage := 1.0          # one-shot per enemy, not per tick (see _hit_enemies)
var pull := 120.0          # px/s drag, scaled down per-enemy as its pull resistance builds
var life := 3.0
var slow_mult := 0.45      # Haste-scaled at spawn: lower = more intense slow
var wave_interval := 1.0   # Haste-scaled at spawn: seconds between cold-wave pulses
var freeze_wave_threshold := 3  # cold waves an enemy must catch before it fully freezes
var freeze_dur := 1.0      # Duration-scaled: how long the freeze lasts once triggered

var spin := 0.0
var wave_timer := 0.0
var wave_hits := {}        # enemy id -> cold waves caught since its last freeze
var pull_factor := {}      # enemy id -> remaining pull grip (1 -> 0 as it resists)
var _hit_enemies := {}     # enemy id -> true: base `damage` lands once per enemy, not per tick


func _ready() -> void:
	z_index = -1
	wave_timer = wave_interval


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	spin += 2.4 * delta
	queue_redraw()

	wave_timer -= delta
	if wave_timer <= 0.0:
		wave_timer += wave_interval
		_emit_cold_wave()

	for e in EnemyGrid.near(global_position, radius):
		var d := global_position.distance_to(e.global_position)
		if d > radius + e.radius:
			continue
		if not e.pull_immune:
			var id := e.get_instance_id()
			var f: float = pull_factor.get(id, 1.0)
			if f > 0.0:
				e.global_position = e.global_position.move_toward(global_position, pull * f * delta)
			pull_factor[id] = maxf(f - 0.6 * delta, 0.0)
		e.apply_slow(slow_mult, 0.5)
		if damage > 0.0:
			var id := e.get_instance_id()
			if not _hit_enemies.has(id):
				_hit_enemies[id] = true
				if is_instance_valid(source_weapon):
					source_weapon.damage_dealt += damage
				e.take_hit(damage, global_position, Enemy.DMG_ICE, source_pid)


func _emit_cold_wave() -> void:
	var fx := RingFx.new()
	fx.position = global_position
	fx.radius = 12.0
	fx.max_radius = radius
	fx.life = 0.45
	fx.color = Color(0.78, 0.95, 1.0, 0.8)
	get_parent().add_child(fx)
	Sfx.play("frost", global_position, -4.0)
	for e in EnemyGrid.near(global_position, radius):
		if global_position.distance_to(e.global_position) <= radius + e.radius:
			var id := e.get_instance_id()
			var hits: int = wave_hits.get(id, 0) + 1
			if hits >= freeze_wave_threshold:
				e.apply_freeze(freeze_dur)
				wave_hits[id] = 0
			else:
				wave_hits[id] = hits


func _draw() -> void:
	var a := clampf(life / 0.5, 0.0, 1.0)  # quick fade-out at the end
	for i in 3:
		var r := radius * (0.35 + 0.3 * i)
		var start := spin * (0.5 + 0.15 * i)
		draw_arc(Vector2.ZERO, r, start, start + TAU * 0.65, 28,
			Color(0.75, 0.92, 1.0, (0.45 - 0.1 * i) * a), 3.0)
	for i in 8:
		var dir := Vector2.from_angle(spin * 0.3 + TAU * float(i) / 8.0)
		draw_line(dir * radius * 0.18, dir * radius * 0.55, Color(0.85, 0.97, 1.0, 0.5 * a), 2.0)
	var core := PackedVector2Array([
		Vector2(0, -13), Vector2(11, 0), Vector2(0, 13), Vector2(-11, 0),
	])
	var inner := PackedVector2Array([
		Vector2(0, -6), Vector2(5, 0), Vector2(0, 6), Vector2(-5, 0),
	])
	draw_colored_polygon(core, Color(0.82, 0.96, 1.0, 0.85 * a))
	draw_colored_polygon(inner, Color(1.0, 1.0, 1.0, 0.7 * a))
