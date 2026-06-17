# --- glaive + missiles: homing rockets that burst into glaive shrapnel -------
class_name FusRotorMissile
extends WeaponBase

var cooldown := 1.4
func _init() -> void:
	weapon_id = "fus_rotormissile"
	display_name = "Rotor Missile"
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
	var dmg := 6.1 * fuse_damage() * (1.0 + GameConfig.FUSION_LEVEL_GROWTH * (level - 1))
	for i in count:
		var m := MissileProj.new()
		m.source_pid = player.peer_id
		m.source_weapon = self
		m.damage = dmg
		m.splash = (60.0 + 8.0 * (level - 1)) * fuse_area()
		m.life = 4.0 * fuse_duration()
		m.velocity = Vector2.from_angle(randf() * TAU) * 280.0
		m.shrapnel_count = 2 + count_level()
		m.shrapnel_dmg = 1.0 * fuse_damage() * (1.0 + GameConfig.FUSION_LEVEL_GROWTH * (level - 1))
		m.shrapnel_radius = 12.0 * fuse_area()
		m.position = player.global_position
		player.get_parent().add_child(m)
	Sfx.play("missile", player.global_position)
	cooldown = 2.6 * fuse_rate()
