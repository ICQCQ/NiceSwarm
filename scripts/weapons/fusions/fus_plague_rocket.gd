# --- missiles + venom: homing rockets that burst into a toxic cloud ----------
class_name FusPlagueRocket
extends WeaponBase

var cooldown := 1.3
func _init() -> void:
	weapon_id = "fus_plaguerocket"
	display_name = "Plague Rocket"
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
		m.splash = (70.0 + 10.0 * (level - 1)) * fuse_area()
		m.life = 4.0 * fuse_duration()
		m.velocity = Vector2.from_angle(randf() * TAU) * 280.0
		m.venom_dps = 0.8 * fuse_damage() * (1.0 + 0.35 * (level - 1))
		m.venom_radius = (65.0 + 9.0 * (level - 1)) * fuse_area()
		m.venom_dur = 2.5 * fuse_duration()
		m.position = player.global_position
		player.get_parent().add_child(m)
	Sfx.play("venom", player.global_position)
	cooldown = 2.6 * fuse_rate()
