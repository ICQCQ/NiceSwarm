class_name ConcordeMissile
extends Node2D
## Concorde: a paper-plane missile that flies dead straight and never truly
## dies at the map's edge — it warps to a different side of the arena, re-aims
## at wherever the player is now, and carries on in a new straight line.
## Grows to full size over its first GROW_TIME seconds; both damage and speed
## climb for as long as it stays airborne. Pierces — it never stops for a hit,
## only for running out of its (very long) lifetime.
##
## Deliberately does NOT check EnemyGrid.in_interceptor_zone() (unlike
## Projectile/MissileProj) — an Interceptor's jamming field must never be able
## to snipe something meant to outlive almost everything else on the field.

const GROW_TIME := 3.0

var player_ref: Player
var source_pid := -1
var source_weapon: WeaponBase

var direction := Vector2.RIGHT
var speed := 240.0
var speed_ramp := 12.0   # px/s gained per second airborne
var dmg := 3.0
var dmg_ramp := 0.12     # fraction of base dmg gained per second airborne
var max_size := 24.0     # Area-scaled
var small_size := 5.0
var size := 5.0
var life := 18.0         # Duration-scaled
var age := 0.0
var rehit := 0.4
var hit_cd := {}


func _ready() -> void:
	add_to_group("concorde_missiles")
	z_index = -1
	small_size = max_size * 0.22
	size = small_size
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	age += delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	size = lerpf(small_size, max_size, clampf(age / GROW_TIME, 0.0, 1.0))
	speed += speed_ramp * delta
	rotation = direction.angle()
	global_position += direction * speed * delta
	_check_warp()
	_check_hits(delta)
	queue_redraw()


func _check_warp() -> void:
	var a := GameConfig.ARENA
	if global_position.x < a.position.x or global_position.x > a.end.x \
			or global_position.y < a.position.y or global_position.y > a.end.y:
		_warp(a)


## Hops to a random *different* side of the arena and re-aims at the player's
## current position — it never just dies at the border.
func _warp(a: Rect2) -> void:
	var left_side := 0
	if global_position.x >= a.end.x:
		left_side = 1
	elif global_position.y <= a.position.y:
		left_side = 2
	elif global_position.y >= a.end.y:
		left_side = 3
	var sides := [0, 1, 2, 3]
	sides.erase(left_side)
	var side: int = sides[randi() % sides.size()]
	var margin := size + 4.0
	match side:
		0: global_position = Vector2(a.position.x + margin, randf_range(a.position.y + margin, a.end.y - margin))
		1: global_position = Vector2(a.end.x - margin, randf_range(a.position.y + margin, a.end.y - margin))
		2: global_position = Vector2(randf_range(a.position.x + margin, a.end.x - margin), a.position.y + margin)
		3: global_position = Vector2(randf_range(a.position.x + margin, a.end.x - margin), a.end.y - margin)
	if player_ref != null and is_instance_valid(player_ref):
		direction = (player_ref.global_position - global_position).normalized()
	hit_cd.clear()  # a fresh leg — let it strike the same foes again
	Sfx.play("concorde", global_position, -6.0)


func _check_hits(delta: float) -> void:
	var expired := []
	for k in hit_cd:
		hit_cd[k] -= delta
		if hit_cd[k] <= 0.0:
			expired.append(k)
	for k in expired:
		hit_cd.erase(k)
	var cur_dmg := dmg * (1.0 + dmg_ramp * age)
	for e in EnemyGrid.near(global_position, size):
		var id := e.get_instance_id()
		if hit_cd.has(id):
			continue
		if global_position.distance_to(e.global_position) <= size + e.radius:
			hit_cd[id] = rehit
			if is_instance_valid(source_weapon):
				source_weapon.damage_dealt += cur_dmg
			e.take_hit(cur_dmg, global_position, Enemy.DMG_PHYS, source_pid)


func _draw() -> void:
	var s := size
	var pts := PackedVector2Array([
		Vector2(s * 1.3, 0.0),
		Vector2(-s * 0.9, -s * 0.6),
		Vector2(-s * 0.4, 0.0),
		Vector2(-s * 0.9, s * 0.6),
	])
	draw_polygon(pts, PackedColorArray([Color(0.92, 0.92, 0.88)]))
	draw_line(Vector2(-s * 0.4, 0.0), Vector2(s * 1.3, 0.0), Color(0.55, 0.55, 0.5), 1.5)
