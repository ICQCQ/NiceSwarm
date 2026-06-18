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
	if player.nearest_enemy(cfg.range) == null:
		cooldown = 0.2
		return
	var count: int = cfg.count_base + count_level()
	var dmg: float = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	for i in count:
		var m := MissileProj.new()
		m.source_pid = player.peer_id
		m.source_weapon = self
		m.damage = dmg
		m.splash = (cfg.splash_base + cfg.splash_per_count * (count_level() - 1)) * fuse_area()
		m.life = cfg.life * fuse_duration()
		m.velocity = Vector2.from_angle(randf() * TAU) * cfg.speed
		m.freeze_slow = cfg.freeze_slow
		m.freeze_dur = dmg * cfg.freeze_dur_ratio * fuse_duration()
		m.position = player.global_position
		player.get_parent().add_child(m)
	Sfx.play("missile", player.global_position)
	cooldown = cfg.cd * fuse_rate()
