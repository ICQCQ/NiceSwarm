# --- flame + missiles: homing rockets that leave a burning crater -------------
class_name FusPhoenixRocket
extends WeaponBase

var cooldown := 1.3
func _init() -> void:
	weapon_id = "fus_phoenixrocket"
	display_name = "Phoenix Rocket"
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
		m.fire_dps = cfg.fire_dps * fuse_damage() * (1.0 + cfg.secondary_growth * (level - 1))
		m.fire_radius = (cfg.fire_radius + cfg.fire_radius_per_level * (level - 1)) * fuse_area()
		m.fire_dur = cfg.fire_dur * fuse_duration()
		m.position = player.global_position
		player.get_parent().add_child(m)
	Sfx.play("missile", player.global_position)
	cooldown = cfg.cd * fuse_rate()
