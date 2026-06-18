# --- laser + lightning: rotating beams that arc lightning on hit -------------
class_name FusIonStorm
extends WeaponBase

var angle := 0.0
var hit_cd := {}
func _init() -> void:
	weapon_id = "fus_ionstorm"
	display_name = "Ion Storm"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		queue_redraw()
		return
	angle = fmod(angle + cfg.spin / fuse_rate() * delta, TAU)
	queue_redraw()
	var expired := []
	for k in hit_cd:
		hit_cd[k] -= delta
		if hit_cd[k] <= 0.0:
			expired.append(k)
	for k in expired:
		hit_cd.erase(k)
	var beams: int = cfg.beam_base + count_level()
	var length: float = (cfg.length + cfg.length_per_count * (count_level() - 1)) * fuse_area()
	var dmg: float = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	for e in Main.instance.enemies_in_radius(global_position, length + 64.0):
		if hit_cd.has(e.get_instance_id()):
			continue
		var rel: Vector2 = e.global_position - global_position
		for b in beams:
			var dir := Vector2.from_angle(angle + TAU * float(b) / beams)
			var along := clampf(rel.dot(dir), 0.0, length)
			if (dir * along).distance_to(rel) <= cfg.beam_width + e.radius:
				damage_dealt += dmg
				e.take_hit(dmg, global_position + dir * along, Enemy.DMG_ENERGY, player.peer_id)
				hit_cd[e.get_instance_id()] = cfg.hit_cd * fuse_rate()
				_zap(e, dmg)
				break
func _zap(src: Node2D, dmg: float) -> void:
	var zap_range: float = cfg.zap_range * fuse_area()
	var best: Node2D = null
	var bd := zap_range * zap_range
	for e in Main.instance.enemies_in_radius(src.global_position, zap_range + 64.0):
		if e == src or hit_cd.has(e.get_instance_id()):
			continue
		var d: float = src.global_position.distance_squared_to(e.global_position)
		if d < bd:
			bd = d
			best = e
	if best == null:
		return
	damage_dealt += dmg * cfg.zap_dmg_ratio
	best.take_hit(dmg * cfg.zap_dmg_ratio, src.global_position, Enemy.DMG_ENERGY, player.peer_id)
	hit_cd[best.get_instance_id()] = cfg.hit_cd * fuse_rate()
	var fx := LightningFx.new()
	fx.points = [src.global_position, best.global_position]
	player.get_parent().add_child(fx)
func _draw() -> void:
	if player == null or player.downed:
		return
	var beams: int = cfg.beam_base + count_level()
	var length: float = (cfg.length + cfg.length_per_count * (count_level() - 1)) * fuse_area()
	for b in beams:
		var dir := Vector2.from_angle(angle + TAU * float(b) / beams)
		draw_line(Vector2.ZERO, dir * length, Color(0.7, 0.6, 1.0, 0.22), 12.0)
		draw_line(Vector2.ZERO, dir * length, Color(0.85, 0.8, 1.0), 2.5)
		draw_circle(dir * length, 7.0 * fuse_area(), Color(0.75, 0.7, 1.0))
