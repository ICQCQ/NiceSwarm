# --- lightning + missiles: homing rockets that chain lightning on impact -----
class_name FusEMPMissile
extends WeaponBase

var cooldown := 1.3
func _init() -> void:
	weapon_id = "fus_empmissile"
	display_name = "EMP Missile"
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
		m.splash = (65.0 + 8.0 * (level - 1)) * fuse_area()
		m.life = 4.0 * fuse_duration()
		m.velocity = Vector2.from_angle(randf() * TAU) * 280.0
		m.chain_count = 2 + count_level()
		m.chain_dmg = 1.0 * fuse_damage() * (1.0 + GameConfig.FUSION_LEVEL_GROWTH * (level - 1))
		m.chain_range = 200.0 * fuse_area()
		m.position = player.global_position
		player.get_parent().add_child(m)
	Sfx.play("missile", player.global_position)
	cooldown = 2.6 * fuse_rate()
