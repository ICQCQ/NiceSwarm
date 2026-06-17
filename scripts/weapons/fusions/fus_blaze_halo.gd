# --- flame + orbit: orbiting blades that ignite and pulse fire ---------------
class_name FusBlazeHalo
extends WeaponBase

const ORBIT_R := 80.0
const BLADE_R := 11.0
const HIT_CD := 0.5
var angle := 0.0
var hit_cd := {}
var pulse_cd := 0.0
func _init() -> void:
	weapon_id = "fus_blazehalo"
	display_name = "Blaze Halo"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		queue_redraw()
		return
	angle = fmod(angle + 2.8 / fuse_rate() * delta, TAU)
	queue_redraw()
	var expired := []
	for k in hit_cd:
		hit_cd[k] -= delta
		if hit_cd[k] <= 0.0:
			expired.append(k)
	for k in expired:
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
				e.take_hit(dmg, bp, Enemy.DMG_FIRE, player.peer_id)
				ignite(e, dmg)
				hit_cd[e.get_instance_id()] = HIT_CD * fuse_rate()
				break
	pulse_cd -= delta
	if pulse_cd <= 0.0:
		var radius := (182.0 + 8.0 * (count_level() - 1)) * fuse_area()
		var pdmg := 1.6 * fuse_damage() * (1.0 + 0.4 * (level - 1))
		var any := false
		for e in Main.instance.enemies_in_radius(global_position, radius + 64.0):
			if global_position.distance_to(e.global_position) <= radius + e.radius:
				damage_dealt += pdmg
				e.take_hit(pdmg, global_position, Enemy.DMG_FIRE, player.peer_id)
				ignite(e, pdmg)
				any = true
		if any:
			var fx := RingFx.new()
			fx.position = global_position
			fx.radius = orbit_r
			fx.max_radius = radius
			fx.life = 0.35
			fx.color = Color(1.0, 0.5, 0.15)
			player.get_parent().add_child(fx)
			Sfx.play("flame", global_position)
			pulse_cd = 3.0 * fuse_rate()
		else:
			pulse_cd = 0.3
func _draw() -> void:
	if player == null or player.downed:
		return
	var n := 2 + count_level()
	var orbit_r := ORBIT_R * fuse_area()
	var blade_r := BLADE_R * fuse_area()
	for i in n:
		var p := Vector2.from_angle(angle + TAU * float(i) / n) * orbit_r
		draw_circle(p, blade_r, Color(1.0, 0.5, 0.15))
		draw_circle(p, blade_r * 0.5, Color(1.0, 0.85, 0.3))
