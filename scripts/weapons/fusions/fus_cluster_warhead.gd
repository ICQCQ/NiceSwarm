# --- missiles + nova ---------------------------------------------------------
class_name FusClusterWarhead
extends WeaponBase

var cooldown := 1.4
func _init() -> void:
	weapon_id = "fus_warhead"
	display_name = "Cluster Warhead"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	if player.nearest_enemy(800.0) == null:
		cooldown = 0.2
		return
	var count := 1 + count_level()
	var dmg := 3.8 * fuse_damage() * (1.0 + GameConfig.FUSION_LEVEL_GROWTH * (level - 1))
	for i in count:
		var m := MissileProj.new()
		m.source_pid = player.peer_id
		m.source_weapon = self
		m.damage = dmg
		m.splash = 165.0 * fuse_area()  # bigger mini-nova blast (good area, not a pop)
		m.push_strength = 65.0 * fuse_area()
		m.life = 4.0 * fuse_duration()
		m.velocity = Vector2.from_angle(randf() * TAU) * 300.0
		m.position = player.global_position
		player.get_parent().add_child(m)
	Sfx.play("missile", player.global_position)
	cooldown = 2.6 * fuse_rate()
