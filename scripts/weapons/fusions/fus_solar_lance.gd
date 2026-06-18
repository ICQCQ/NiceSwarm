# --- flame + laser: a continuous searing beam ---------------------------------
class_name FusSolarLance
extends WeaponBase

const TICK := 0.12
var tick := 0.0
func _init() -> void:
	weapon_id = "fus_solarlance"
	display_name = "Solar Lance"
func _physics_process(delta: float) -> void:
	queue_redraw()
	if player == null or player.downed:
		return
	tick -= delta
	if tick > 0.0:
		return
	tick = TICK * fuse_rate()
	var length: float = (cfg.length + cfg.length_per_count * (count_level() - 1)) * fuse_area()
	var width: float = cfg.width * fuse_area()
	var dmg: float = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	var dir := player.facing
	for e in Main.instance.enemies_in_radius(global_position, length + 64.0):
		var rel: Vector2 = e.global_position - global_position
		var along := rel.dot(dir)
		if along >= 0.0 and along <= length and (dir * along).distance_to(rel) <= width + e.radius:
			damage_dealt += dmg
			e.take_hit(dmg, global_position, Enemy.DMG_FIRE, player.peer_id)
			e.apply_burn(dmg * cfg.burn_dps_ratio, cfg.burn_dur * fuse_duration(), 1.0, player.peer_id)
	Sfx.play("laser", global_position, -10.0)
func _draw() -> void:
	if player == null or player.downed:
		return
	var length: float = (cfg.length + cfg.length_per_count * (count_level() - 1)) * fuse_area()
	var dir := player.facing
	draw_line(Vector2.ZERO, dir * length, Color(1.0, 0.5, 0.1, 0.35), cfg.width * fuse_area())
	draw_line(Vector2.ZERO, dir * length, Color(1.0, 0.9, 0.4), 4.0)
