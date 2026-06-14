class_name FrostShard
extends Node2D
## Piercing icy shard: hits up to 3 enemies, slowing each.

var velocity := Vector2.ZERO
var source_pid := -1  # scoreboard: which player owns this
var damage := 1.5
var life := 1.4
var hit_radius := 7.0
var slow_dur := 1.5  # scaled by the weapon's Duration stat
var pierce_left := 3
var hit_ids := {}
var shatter_dmg := 0.0     # fused Frost Lance: bonus AoE when hitting an already-slowed enemy
var shatter_radius := 0.0


func _physics_process(delta: float) -> void:
	position += velocity * delta
	rotation = velocity.angle()
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	for e in EnemyGrid.near(global_position, hit_radius):
		if hit_ids.has(e.get_instance_id()):
			continue
		if global_position.distance_to(e.global_position) <= hit_radius + e.radius:
			hit_ids[e.get_instance_id()] = true
			var was_slowed := e.slow_timer > 0.0
			e.take_hit(damage, global_position, Enemy.DMG_ICE, source_pid)
			e.apply_slow(0.5, slow_dur)
			if was_slowed and shatter_dmg > 0.0:
				_shatter(e)
			pierce_left -= 1
			if pierce_left <= 0:
				queue_free()
				return


func _shatter(center: Enemy) -> void:
	var fx := RingFx.new()
	fx.position = center.global_position
	fx.radius = hit_radius
	fx.max_radius = shatter_radius
	fx.life = 0.25
	fx.color = Color(0.7, 0.9, 1.0)
	get_parent().add_child(fx)
	Sfx.play("frost", center.global_position, -8.0)
	for e in EnemyGrid.near(center.global_position, shatter_radius):
		if center.global_position.distance_to(e.global_position) <= shatter_radius + e.radius:
			e.take_hit(shatter_dmg, center.global_position, Enemy.DMG_ICE, source_pid)
			e.apply_slow(0.5, slow_dur)


func _draw() -> void:
	draw_polygon(
		PackedVector2Array([Vector2(10, 0), Vector2(0, -4), Vector2(-6, 0), Vector2(0, 4)]),
		PackedColorArray([Color(0.7, 0.9, 1.0)])
	)
