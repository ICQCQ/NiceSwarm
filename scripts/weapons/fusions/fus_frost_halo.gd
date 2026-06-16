# --- frost + orbit -----------------------------------------------------------
class_name FusFrostHalo
extends WeaponBase

const BLADE_R := 11.0
const ORBIT_R := 78.0
const HIT_CD := 0.5
var angle := 0.0
var hit_cd := {}
func _init() -> void:
	weapon_id = "fus_frosthalo"
	display_name = "Frost Halo"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		queue_redraw()
		return
	angle = fmod(angle + 2.8 / fuse_rate() * delta, TAU)
	queue_redraw()
	var exp := []
	for k in hit_cd:
		hit_cd[k] -= delta
		if hit_cd[k] <= 0.0:
			exp.append(k)
	for k in exp:
		hit_cd.erase(k)
	var n := 2 + count_level()
	var orbit_r := ORBIT_R * fuse_area()
	var blade_r := BLADE_R * fuse_area()
	var dmg := 2.0 * fuse_damage() * (1.0 + 0.4 * (level - 1))
	for e in Main.instance.enemies_in_radius(global_position, orbit_r + blade_r + 64.0):
		if hit_cd.has(e.get_instance_id()):
			continue
		for i in n:
			var bp: Vector2 = global_position + Vector2.from_angle(angle + TAU * float(i) / n) * orbit_r
			if bp.distance_to(e.global_position) <= blade_r + e.radius:
				damage_dealt += dmg
				e.take_hit(dmg, bp, Enemy.DMG_PHYS, player.peer_id)
				e.apply_slow(0.5, 1.2 * fuse_duration())
				hit_cd[e.get_instance_id()] = HIT_CD * fuse_rate()
				break
func _draw() -> void:
	if player == null or player.downed:
		return
	var n := 2 + count_level()
	var orbit_r := ORBIT_R * fuse_area()
	var blade_r := BLADE_R * fuse_area()
	for i in n:
		var p := Vector2.from_angle(angle + TAU * float(i) / n) * orbit_r
		draw_circle(p, blade_r, Color(0.6, 0.85, 1.0))
		draw_circle(p, blade_r * 0.5, Color(0.85, 0.95, 1.0))
