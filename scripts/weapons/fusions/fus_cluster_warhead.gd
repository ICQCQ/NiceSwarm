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
		m.splash = cfg.splash * fuse_area()  # bigger mini-nova blast (good area, not a pop)
		m.push_strength = cfg.push * fuse_area()
		m.life = cfg.life * fuse_duration()
		m.velocity = Vector2.from_angle(randf() * TAU) * cfg.speed
		m.position = player.global_position
		player.get_parent().add_child(m)
	Sfx.play("missile", player.global_position)
	cooldown = cfg.cd * fuse_rate()
