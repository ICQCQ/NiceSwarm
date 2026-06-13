class_name FrostShard
extends Node2D
## Piercing icy shard: hits up to 3 enemies, slowing each.

var velocity := Vector2.ZERO
var damage := 1.5
var life := 1.4
var hit_radius := 7.0
var slow_dur := 1.5  # scaled by the weapon's Duration stat
var pierce_left := 3
var hit_ids := {}


func _physics_process(delta: float) -> void:
	position += velocity * delta
	rotation = velocity.angle()
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if hit_ids.has(e.get_instance_id()):
			continue
		if global_position.distance_to(e.global_position) <= hit_radius + e.radius:
			hit_ids[e.get_instance_id()] = true
			e.take_hit(damage, global_position, Enemy.DMG_ICE)
			e.apply_slow(0.5, slow_dur)
			pierce_left -= 1
			if pierce_left <= 0:
				queue_free()
				return


func _draw() -> void:
	draw_polygon(
		PackedVector2Array([Vector2(10, 0), Vector2(0, -4), Vector2(-6, 0), Vector2(0, 4)]),
		PackedColorArray([Color(0.7, 0.9, 1.0)])
	)
