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
		m.splash = (cfg.splash + cfg.splash_per_level * (level - 1)) * fuse_area()
		m.life = cfg.life * fuse_duration()
		m.velocity = Vector2.from_angle(randf() * TAU) * cfg.speed
		m.shrapnel_count = cfg.shrapnel_count_base + count_level()
		m.shrapnel_dmg = cfg.shrapnel_dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
		m.shrapnel_radius = cfg.shrapnel_radius * fuse_area()
		m.position = player.global_position
		player.get_parent().add_child(m)
	Sfx.play("missile", player.global_position)
	cooldown = cfg.cd * fuse_rate()
