# --- frost + laser: rotating ice beams that slow on hit ----------------------
class_name FusCryoBeam
extends WeaponBase

const HIT_CD := 0.4
var angle := 0.0
var hit_cd := {}
func _init() -> void:
	weapon_id = "fus_cryobeam"
	display_name = "Cryo Beam"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		queue_redraw()
		return
	angle = fmod(angle + 1.6 / fuse_rate() * delta, TAU)
	queue_redraw()
	var expired := []
	for k in hit_cd:
		hit_cd[k] -= delta
		if hit_cd[k] <= 0.0:
			expired.append(k)
	for k in expired:
		hit_cd.erase(k)
	var beams := 1 + count_level()
	var length := (170.0 + 25.0 * (level - 1)) * fuse_area()
	var dmg := 1.2 * fuse_damage() * (1.0 + 0.4 * (level - 1))
	for e in Main.instance.enemies_in_radius(global_position, length + 64.0):
		if hit_cd.has(e.get_instance_id()):
			continue
		var rel: Vector2 = e.global_position - global_position
		for b in beams:
			var dir := Vector2.from_angle(angle + TAU * float(b) / beams)
			var along := clampf(rel.dot(dir), 0.0, length)
			if (dir * along).distance_to(rel) <= 9.0 + e.radius:
				damage_dealt += dmg
				e.take_hit(dmg, global_position + dir * along, Enemy.DMG_ICE, player.peer_id)
				e.apply_slow(0.5, dmg * 0.4 * fuse_duration())
				hit_cd[e.get_instance_id()] = HIT_CD * fuse_rate()
				Sfx.play("frost", e.global_position, -5.0)
				break
func _draw() -> void:
	if player == null or player.downed:
		return
	var beams := 1 + count_level()
	var length := (170.0 + 25.0 * (level - 1)) * fuse_area()
	for b in beams:
		var dir := Vector2.from_angle(angle + TAU * float(b) / beams)
		draw_line(Vector2.ZERO, dir * length, Color(0.5, 0.85, 1.0, 0.22), 12.0)
		draw_line(Vector2.ZERO, dir * length, Color(0.8, 0.95, 1.0), 2.5)
		draw_circle(dir * length, 7.0 * fuse_area(), Color(0.6, 0.9, 1.0))
