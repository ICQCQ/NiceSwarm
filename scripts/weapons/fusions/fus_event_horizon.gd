# --- gravity + orbit: hold enemies in a blade ring ---------------------------
class_name FusEventHorizon
extends WeaponBase

const ORBIT_R := 88.0
const BLADE_R := 12.0
const HIT_CD := 0.4
var angle := 0.0
var hit_cd := {}
func _init() -> void:
	weapon_id = "fus_eventhorizon"
	display_name = "Event Horizon"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		queue_redraw()
		return
	angle = fmod(angle + 3.2 / fuse_rate() * delta, TAU)
	queue_redraw()
	var orbit_r := ORBIT_R * fuse_area()
	var pull_r := orbit_r * 2.4
	for e in Main.instance.enemies_in_radius(global_position, pull_r + 64.0):
		if e.pull_immune:
			continue
		var off: Vector2 = e.global_position - global_position
		if off.length() <= pull_r:
			var ring_point: Vector2 = global_position + off.normalized() * orbit_r
			e.global_position = e.global_position.move_toward(ring_point, 90.0 * delta)
	var expired := []
	for k in hit_cd:
		hit_cd[k] -= delta
		if hit_cd[k] <= 0.0:
			expired.append(k)
	for k in expired:
		hit_cd.erase(k)
	var n := 2 + count_level()
	var blade_r := BLADE_R * fuse_area()
	var dmg := 2.2 * fuse_damage() * (1.0 + 0.4 * (level - 1))
	for e in Main.instance.enemies_in_radius(global_position, orbit_r + blade_r + 64.0):
		if hit_cd.has(e.get_instance_id()):
			continue
		for i in n:
			var bp: Vector2 = global_position + Vector2.from_angle(angle + TAU * float(i) / n) * orbit_r
			if bp.distance_to(e.global_position) <= blade_r + e.radius:
				damage_dealt += dmg
				e.take_hit(dmg, bp, Enemy.DMG_ENERGY, player.peer_id)
				hit_cd[e.get_instance_id()] = HIT_CD * fuse_rate()
				break
func _draw() -> void:
	if player == null or player.downed:
		return
	var orbit_r := ORBIT_R * fuse_area()
	var blade_r := BLADE_R * fuse_area()
	draw_arc(Vector2.ZERO, orbit_r, 0.0, TAU, 40, Color(0.6, 0.4, 0.9, 0.25), 2.0)
	var n := 2 + count_level()
	for i in n:
		var p := Vector2.from_angle(angle + TAU * float(i) / n) * orbit_r
		draw_circle(p, blade_r, Color(0.8, 0.6, 1.0))
		draw_circle(p, blade_r * 0.5, Color(0.4, 0.25, 0.6))
