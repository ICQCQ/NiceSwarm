# --- bolt + frost ------------------------------------------------------------
class_name FusFrostLance
extends WeaponBase

var cooldown := 0.5
func _init() -> void:
	weapon_id = "fus_frostlance"
	display_name = "Frost Lance"
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
	var base := (target.global_position - player.global_position).normalized()
	var count: int = cfg.count_base + count_level()
	var shatter_dmg: float = cfg.shatter_dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	var shatter_radius: float = (cfg.shatter_radius_base + cfg.shatter_radius_per_level * (level - 1)) * fuse_area()
	for i in count:
		var s := FrostShard.new()
		s.source_pid = player.peer_id
		s.source_weapon = self
		s.velocity = base.rotated(deg_to_rad(cfg.spread_deg * (i - (count - 1) / 2.0))) * cfg.speed
		s.damage = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
		s.hit_radius = cfg.hit_radius * fuse_area()
		s.life = cfg.life * fuse_duration()
		s.slow_dur = cfg.slow_dur * fuse_duration()
		s.pierce_left = cfg.pierce
		s.shatter_dmg = shatter_dmg  # lances that strike an already-frozen foe shatter it
		s.shatter_radius = shatter_radius
		s.position = player.global_position
		player.get_parent().add_child(s)
	Sfx.play("frost", player.global_position)
	cooldown = cfg.cd * fuse_rate()
