# --- flame + frost: burn + freeze cone ---------------------------------------
class_name FusThermalShock
extends WeaponBase

var tick := 0.0
func _init() -> void:
	weapon_id = "fus_thermal"
	display_name = "Thermal Shock"
func _physics_process(delta: float) -> void:
	queue_redraw()
	if player == null or player.downed:
		return
	tick -= delta
	if tick > 0.0:
		return
	tick = cfg.cd * fuse_rate()
	var reach: float = (cfg.reach + cfg.reach_per_level * (level - 1)) * fuse_area()
	var dmg: float = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	var half: float = cfg.half_angle
	var any := false
	for e in Main.instance.enemies_in_radius(player.global_position, reach + 64.0):
		var to: Vector2 = e.global_position - player.global_position
		if to.length() <= reach + e.radius and absf(player.facing.angle_to(to)) <= half:
			damage_dealt += dmg
			e.take_hit(dmg, null, Enemy.DMG_FIRE, player.peer_id)
			ignite(e, dmg)
			e.apply_slow(cfg.slow_mult, cfg.slow_dur * fuse_duration())
			any = true
	if any:
		Sfx.play("flame", player.global_position)
func _draw() -> void:
	if player == null or player.downed:
		return
	var reach: float = (cfg.reach + cfg.reach_per_level * (level - 1)) * fuse_area()
	var half: float = cfg.half_angle
	var base_a := player.facing.angle()
	for i in 7:
		var ang := base_a + randf_range(-half * 0.8, half * 0.8)
		var dist := randf_range(reach * 0.25, reach)
		var col := Color(1.0, 0.5, 0.2) if randf() < 0.5 else Color(0.5, 0.85, 1.0)
		draw_circle(Vector2.from_angle(ang) * dist, randf_range(4.0, 10.0),
			Color(col.r, col.g, col.b, randf_range(0.3, 0.6)))
