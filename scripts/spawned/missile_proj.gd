class_name MissileProj
extends Node2D
## Homing missile: steers toward its target, explodes with splash damage.

var damage := 3.0
var splash := 70.0
var velocity := Vector2.ZERO
var life := 4.0
var target: Node2D


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	if target == null or not is_instance_valid(target):
		target = _find_target()
	if target != null:
		var desired := (target.global_position - global_position).normalized() * 380.0
		velocity = velocity.lerp(desired, 4.0 * delta)
	position += velocity * delta
	rotation = velocity.angle()
	queue_redraw()
	if target != null and is_instance_valid(target) \
			and global_position.distance_to(target.global_position) <= 10.0 + target.radius:
		_explode()


func _find_target() -> Node2D:
	var best: Node2D = null
	var best_d := 800.0 * 800.0
	for e in Main.instance.all_enemies():
		var d: float = global_position.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _explode() -> void:
	var fx := RingFx.new()
	fx.position = global_position
	fx.radius = 12.0
	fx.max_radius = splash
	fx.life = 0.25
	fx.color = Color(1.0, 0.6, 0.3)
	get_parent().add_child(fx)
	Sfx.play("boom", global_position, -10.0)
	for e in Main.instance.all_enemies():
		if global_position.distance_to(e.global_position) <= splash + e.radius:
			e.take_hit(damage, global_position)
	queue_free()


func _draw() -> void:
	draw_polygon(
		PackedVector2Array([Vector2(9, 0), Vector2(-6, -5), Vector2(-6, 5)]),
		PackedColorArray([Color(0.85, 0.85, 0.9)])
	)
	draw_circle(Vector2(-7, 0), 2.5, Color(1.0, 0.6, 0.2, randf_range(0.5, 1.0)))
