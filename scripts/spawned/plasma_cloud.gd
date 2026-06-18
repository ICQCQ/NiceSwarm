class_name PlasmaCloud
extends Node2D
## Plasma Storm cloud: drifts in a fixed straight line (the angle is locked at
## spawn, toward whatever was nearest then — it never re-tracks), slowing to a
## stop once it covers max_dist. Continuously burns anything touching it and
## periodically arcs lightning out to nearby enemies from wherever it's drifted to.

var velocity := Vector2.ZERO  # constant; zeroed once max_dist is covered
var traveled := 0.0
var max_dist := 260.0
var radius := 65.0
var life := 5.0
var max_life := 5.0
var dps := 2.0
var lightning_interval := 0.9
var lightning_dmg := 4.5
var chain_count := 2
var chain_range := 190.0
var source_pid := -1
var source_weapon: WeaponBase
var lightning_cd := 0.0
var tick := 0.0
var redraw_tick := 0.0


func _ready() -> void:
	add_to_group("plasma_clouds")
	z_index = -1
	queue_redraw()


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	if traveled < max_dist:
		var step: Vector2 = velocity * delta
		position += step
		traveled += step.length()
	redraw_tick -= delta
	if redraw_tick <= 0.0:
		redraw_tick = 0.1
		queue_redraw()
	tick -= delta
	if tick <= 0.0:
		tick = 0.4
		for e in EnemyGrid.near(global_position, radius):
			if global_position.distance_to(e.global_position) <= radius + e.radius:
				if is_instance_valid(source_weapon):
					source_weapon.damage_dealt += dps
				e.take_hit(dps, null, Enemy.DMG_FIRE, source_pid)
				e.apply_burn(dps * 0.6, 1.0)
	lightning_cd -= delta
	if lightning_cd <= 0.0:
		lightning_cd = lightning_interval
		_emit_lightning()


func _emit_lightning() -> void:
	var visited := {}
	var cur: Node2D = _nearest(global_position, visited)
	if cur == null:
		return
	var pts: Array = [global_position]
	var left := chain_count
	while cur != null and left > 0:
		visited[cur.get_instance_id()] = true
		pts.append(cur.global_position)
		if is_instance_valid(source_weapon):
			source_weapon.damage_dealt += lightning_dmg
		cur.take_hit(lightning_dmg, null, Enemy.DMG_ENERGY, source_pid)
		left -= 1
		cur = _nearest(pts[pts.size() - 1], visited)
	if pts.size() > 1:
		var fx := LightningFx.new()
		fx.points = pts
		get_parent().add_child(fx)
		Sfx.play("lightning", global_position)


func _nearest(from: Vector2, visited: Dictionary) -> Node2D:
	var best: Node2D = null
	var bd: float = chain_range * chain_range
	for e in EnemyGrid.near(from, chain_range):
		if visited.has(e.get_instance_id()):
			continue
		var d: float = from.distance_squared_to(e.global_position)
		if d < bd:
			bd = d
			best = e
	return best


func _draw() -> void:
	var a := clampf(life / max_life, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius, Color(0.85, 0.2, 0.15, 0.16 * a))
	draw_circle(Vector2(radius * 0.3, -radius * 0.2), radius * 0.32, Color(1.0, 0.4, 0.2, 0.22 * a))
	draw_circle(Vector2(-radius * 0.32, radius * 0.22), radius * 0.24, Color(1.0, 0.3, 0.15, 0.2 * a))
	draw_circle(Vector2(radius * 0.05, radius * 0.3), radius * 0.2, Color(1.0, 0.5, 0.25, 0.18 * a))
