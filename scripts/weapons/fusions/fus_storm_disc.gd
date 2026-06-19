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
	var count: int = cfg.count_base + count_level()
	if owned_in_group("storm_shurikens") >= count:
		cooldown = 0.1
		return
	var dmg: float = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	var hit_radius: float = cfg.hit_radius * fuse_area()
	var s := StormShuriken.new()
	s.player = player
	s.weapon = self
	s.source_pid = player.peer_id
	s.owner_weapon_id = get_instance_id()
	s.damage = dmg * cfg.dmg_ratio
	s.arc_damage = dmg * cfg.arc_dmg_ratio
	s.age_dmg_growth = cfg.age_dmg_growth
	s.arc_range = cfg.arc_range * fuse_area()
	s.hit_radius = hit_radius
	# Player.RADIUS, not hit_radius, anchors this -- it's "did the shuriken actually
	# touch you", independent of how big the blade got from Area.
	s.contact_radius = Player.RADIUS + 6.0 * fuse_area()
	s.patrol_range = cfg.patrol_range * fuse_duration()
	s.speed = cfg.speed
	s.fly_back_speed_mult = cfg.fly_back_speed_mult
	s.max_speed_growth = cfg.max_speed_growth
	s.min_speed = cfg.min_speed
	s.out_angle_spread_deg = cfg.out_angle_spread_deg
	s.recall_grace = cfg.recall_grace
	s.recall_cd_penalty = cfg.recall_cd_penalty
	s.position = player.global_position
	player.get_parent().add_child(s)
	Sfx.play("lightning", player.global_position)
	cooldown = cfg.cd * fuse_rate()
