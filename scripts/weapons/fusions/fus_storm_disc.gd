# --- glaive + lightning ------------------------------------------------------
class_name FusStormDisc
extends WeaponBase

var cooldown := 0.9
func _init() -> void:
	weapon_id = "fus_storm"
	display_name = "Storm Disc"
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
		g.arc_damage = dmg * cfg.arc_dmg_ratio
		g.arc_range = cfg.arc_range * fuse_area()
		g.position = player.global_position
		player.get_parent().add_child(g)
	Sfx.play("lightning", player.global_position)
	cooldown = cfg.cd * fuse_rate()
