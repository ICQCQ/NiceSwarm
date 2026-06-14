class_name GlaiveProj
extends Node2D
## Boomerang glaive: decelerates outward, then returns to the player.
## Pierces everything; each enemy can be hit once per phase (out / return).

const DECEL := 700.0
const RETURN_SPEED := 540.0

var player: Player
var velocity := Vector2.ZERO
var damage := 2.0
var hit_radius := 14.0
var slow_factor := 1.0  # <1 = fused ice glaive slows on hit
var arc_damage := 0.0   # fused Storm Disc: arcs lightning to a nearby foe on hit
var arc_range := 150.0
var returning := false
var spin := 0.0
var hit_ids := {}


func _physics_process(delta: float) -> void:
	spin += 14.0 * delta
	if not returning:
		velocity = velocity.move_toward(Vector2.ZERO, DECEL * delta)
		position += velocity * delta
		if velocity.length() < 12.0:
			returning = true
			hit_ids.clear()  # can hit everyone again on the way back
	else:
		if player == null or not is_instance_valid(player):
			queue_free()
			return
		var dir := (player.global_position - global_position).normalized()
		position += dir * RETURN_SPEED * delta
		if global_position.distance_to(player.global_position) < 24.0:
			queue_free()
			return
	queue_redraw()

	for e in Main.instance.all_enemies():
		if hit_ids.has(e.get_instance_id()):
			continue
		if global_position.distance_to(e.global_position) <= hit_radius + e.radius:
			hit_ids[e.get_instance_id()] = true
			e.take_hit(damage, global_position)
			if player != null:  # Duration: glaive leaves a bleed/burn
				e.apply_burn(damage * 0.3, 1.2 * player.duration_mult)
			if slow_factor < 1.0:  # set by fused Glacial variants
				e.apply_slow(slow_factor, 1.5 * (player.duration_mult if player else 1.0))
			if arc_damage > 0.0:
				_arc_from(e)


func _arc_from(src: Node2D) -> void:
	var best: Node2D = null
	var bd := arc_range * arc_range
	for e in Main.instance.all_enemies():
		if e == src or hit_ids.has(e.get_instance_id()):
			continue
		var d: float = src.global_position.distance_squared_to(e.global_position)
		if d < bd:
			bd = d
			best = e
	if best == null:
		return
	best.take_hit(arc_damage, src.global_position)
	var fx := LightningFx.new()
	fx.points = [src.global_position, best.global_position]
	get_parent().add_child(fx)


func _draw() -> void:
	for i in 3:
		var a := spin + TAU * float(i) / 3.0
		draw_line(Vector2.ZERO, Vector2.from_angle(a) * 14.0, Color(0.75, 1.0, 0.9), 3.0)
	draw_circle(Vector2.ZERO, 4.0, Color(0.45, 0.9, 0.8))
