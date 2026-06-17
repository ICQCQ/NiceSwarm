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
	var target := player.nearest_enemy(700.0)
	if target == null:
		cooldown = 0.1
		return
	var base := (target.global_position - player.global_position).normalized()
	var count := 2 + count_level()
	var shatter_dmg := 4.6 * fuse_damage() * (1.0 + GameConfig.FUSION_LEVEL_GROWTH * (level - 1))
	var shatter_radius := (60.0 + 12.0 * (level - 1)) * fuse_area()
	for i in count:
		var s := FrostShard.new()
		s.source_pid = player.peer_id
		s.source_weapon = self
		s.velocity = base.rotated(deg_to_rad(6.0 * (i - (count - 1) / 2.0))) * 620.0
		s.damage = 4.1 * fuse_damage() * (1.0 + GameConfig.FUSION_LEVEL_GROWTH * (level - 1))
		s.hit_radius = 8.0 * fuse_area()
		s.life = 1.6 * fuse_duration()
		s.slow_dur = 1.4 * fuse_duration()
		s.pierce_left = 4
		s.shatter_dmg = shatter_dmg  # lances that strike an already-frozen foe shatter it
		s.shatter_radius = shatter_radius
		s.position = player.global_position
		player.get_parent().add_child(s)
	Sfx.play("frost", player.global_position)
	cooldown = 1.0 * fuse_rate()
