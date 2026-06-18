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
		m.splash = (cfg.splash_base + cfg.splash_per_level * (level - 1)) * fuse_area()
		m.life = cfg.life * fuse_duration()
		m.velocity = Vector2.from_angle(randf() * TAU) * cfg.speed
		m.chain_count = cfg.chain_count_base + count_level()
		m.chain_dmg = cfg.chain_dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
		m.chain_range = cfg.chain_range * fuse_area()
		m.position = player.global_position
		player.get_parent().add_child(m)
	Sfx.play("missile", player.global_position)
	cooldown = cfg.cd * fuse_rate()
