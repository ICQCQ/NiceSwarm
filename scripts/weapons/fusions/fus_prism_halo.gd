# --- laser + orbit -----------------------------------------------------------
class_name FusPrismHalo
extends WeaponBase

const HIT_CD := 0.35
var angle := 0.0
var hit_cd := {}
func _init() -> void:
	weapon_id = "fus_prism"
	display_name = "Prism Halo"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		queue_redraw()
		return
	angle = fmod(angle + 2.2 / fuse_rate() * delta, TAU)
	queue_redraw()
	var exp := []
	for k in hit_cd:
		hit_cd[k] -= delta
		if hit_cd[k] <= 0.0:
			exp.append(k)
	for k in exp:
		hit_cd.erase(k)
	var spokes: int = cfg.count_base + count_level()
	var length: float = (cfg.length + cfg.length_per_count * (count_level() - 1)) * fuse_area()
	var dmg: float = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	var hit_radius: float = cfg.hit_radius
	for e in Main.instance.enemies_in_radius(global_position, length + 64.0):
		if hit_cd.has(e.get_instance_id()):
			continue
		var rel: Vector2 = e.global_position - global_position
		for s in spokes:
			var dir := Vector2.from_angle(angle + TAU * float(s) / spokes)
			var along := clampf(rel.dot(dir), 0.0, length)
			if (dir * along).distance_to(rel) <= hit_radius + e.radius:
				damage_dealt += dmg
				e.take_hit(dmg, global_position + dir * along, Enemy.DMG_PHYS, player.peer_id)
				ignite(e, dmg)
				hit_cd[e.get_instance_id()] = HIT_CD * fuse_rate()
				Sfx.play("laser", e.global_position)
				break
func _draw() -> void:
	if player == null or player.downed:
		return
	var spokes: int = cfg.count_base + count_level()
	var length: float = (cfg.length + cfg.length_per_count * (count_level() - 1)) * fuse_area()
	for s in spokes:
		var dir := Vector2.from_angle(angle + TAU * float(s) / spokes)
		draw_line(Vector2.ZERO, dir * length, Color(0.8, 0.5, 1.0, 0.3), 7.0)
		draw_line(Vector2.ZERO, dir * length, Color(1.0, 0.85, 1.0), 2.5)
		draw_circle(dir * length, 6.0 * fuse_area(), Color(0.85, 0.6, 1.0))
