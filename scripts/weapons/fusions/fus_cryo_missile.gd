# --- frost + missiles: homing missiles that slow on splash -------------------
class_name FusCryoMissile
extends WeaponBase

var cooldown := 1.2
func _init() -> void:
	weapon_id = "fus_cryomissile"
	display_name = "Cryo Missile"
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
		m.splash = (116.0 + 6.0 * (count_level() - 1)) * fuse_area()
		m.life = 4.0 * fuse_duration()
		m.velocity = Vector2.from_angle(randf() * TAU) * 280.0
		m.freeze_slow = 0.5
		m.freeze_dur = dmg * 0.35 * fuse_duration()
		m.position = player.global_position
		player.get_parent().add_child(m)
	Sfx.play("missile", player.global_position)
	cooldown = 2.5 * fuse_rate()
