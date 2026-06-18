# --- frost + glaive ----------------------------------------------------------
class_name FusGlacialEdge
extends WeaponBase

var cooldown := 0.8
func _init() -> void:
	weapon_id = "fus_glacial"
	display_name = "Glacial Edge"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	var target := player.nearest_enemy(cfg.range)
	if target == null:
		cooldown = 0.1
		return
	var count: int = cfg.count_base + count_level()
	var base := (target.global_position - player.global_position).normalized()
	var dmg: float = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	for i in count:
		var g := GlaiveProj.new()
		g.source_pid = player.peer_id
		g.source_weapon = self
		g.player = player
		g.velocity = base.rotated(deg_to_rad(cfg.spread_deg) * (i - (count - 1) / 2.0)) * cfg.speed
		g.damage = dmg * cfg.dmg_ratio
		g.burn_dps = dmg * cfg.burn_dps_ratio
		g.hit_radius = cfg.hit_radius * fuse_area()
		g.slow_factor = cfg.slow_factor
		g.position = player.global_position
		player.get_parent().add_child(g)
	Sfx.play("frost", player.global_position)
	cooldown = cfg.cd * fuse_rate()
