class_name GrenadeProj
extends Node2D
## Bouncy Grenade: hops from enemy to enemy, exploding on every landing. Each
## hop arcs (visual height offset) instead of flying straight; the final hop
## in the chain detonates for the biggest hit.
##
## Deliberately does NOT check EnemyGrid.in_interceptor_zone() (unlike
## Projectile/MissileProj) -- a slow, lobbed grenade chain is meant to be able
## to land inside an Interceptor's jamming field, not get sniped crossing it.

var source_pid := -1
var source_weapon: WeaponBase
var start_pos := Vector2.ZERO
var land_pos := Vector2.ZERO
var t := 0.0
var travel_time := 0.7
var hop_height := 70.0
var dmg := 0.0
var final_dmg_mult := 2.5
var blast_radius := 50.0
var final_radius_mult := 1.3
var hops_left := 0   # hops still to perform AFTER this one lands
var range_min := 0.0
var range_max := 0.0


func _physics_process(delta: float) -> void:
	t += delta
	var p := clampf(t / travel_time, 0.0, 1.0)
	position = start_pos.lerp(land_pos, p)
	queue_redraw()
	if p >= 1.0:
		_land()


func _land() -> void:
	var is_final := hops_left <= 0
	_explode(blast_radius * (final_radius_mult if is_final else 1.0), dmg * (final_dmg_mult if is_final else 1.0))
	if is_final:
		queue_free()
		return
	var next_target := _pick_target(global_position)
	if next_target == null:
		queue_free()
		return
	hops_left -= 1
	start_pos = global_position
	land_pos = next_target.global_position
	travel_time = clampf(start_pos.distance_to(land_pos) / 150.0, 0.8, 2.2)
	t = 0.0


func _pick_target(from: Vector2) -> Node2D:
	var near := EnemyGrid.near(from, range_max)
	var candidates: Array = []
	for e in near:
		var d := from.distance_to(e.global_position)
		if d <= range_max and d >= range_min:
			candidates.append(e)
	if candidates.is_empty():
		for e in near:
			if from.distance_to(e.global_position) <= range_max:
				candidates.append(e)
	if candidates.is_empty():
		return null
	return candidates[randi() % candidates.size()]


func _explode(radius: float, damage: float) -> void:
	var fx := RingFx.new()
	fx.position = global_position
	fx.radius = 10.0
	fx.max_radius = radius
	fx.life = 0.22
	fx.color = Color(0.55, 0.9, 0.4)
	get_parent().add_child(fx)
	Sfx.play("boom", global_position, -8.0)
	for e in EnemyGrid.near(global_position, radius):
		if global_position.distance_to(e.global_position) <= radius + e.radius:
			if is_instance_valid(source_weapon):
				source_weapon.damage_dealt += damage
			e.take_hit(damage, global_position, Enemy.DMG_PHYS, source_pid)


func _draw() -> void:
	# Visual hop: rises then falls over the lerp instead of sliding flat.
	var p := clampf(t / travel_time, 0.0, 1.0)
	var arc := sin(p * PI) * hop_height
	draw_circle(Vector2(0, -arc), 7.0, Color(0.3, 0.5, 0.28))
	draw_circle(Vector2(0, -arc), 3.0, Color(0.6, 0.9, 0.4))
