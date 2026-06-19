# --- gravity + nova ----------------------------------------------------------
class_name FusSingularity
extends WeaponBase

var cooldown := 2.5
func _init() -> void:
	weapon_id = "fus_singularity"
	display_name = "Singularity"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	var target := player.nearest_enemy(cfg.range)
	if target == null:
		cooldown = 0.2
		return
	var w := GravityWell.new()
	w.source_pid = player.peer_id
	w.source_weapon = self
	w.radius = (cfg.radius + cfg.radius_per_count * (count_level() - 1)) * fuse_area()
	w.damage = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))  # re-anchored: Lv1 ≈ two max-level base weapons
	w.pull = cfg.pull
	w.pull_interval = cfg.pull_interval * fuse_rate()  # Haste: periodic yank, not a continuous drag
	w.life = cfg.life * fuse_duration()
	w.detonate_damage = cfg.detonate_dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))  # re-anchored: nova @L7 (13.35 eff)
	w.detonate_scale_per_enemy = cfg.detonate_scale_per_enemy
	w.push_strength = cfg.push * fuse_area()  # meatier collapse shockwave
	w.position = target.global_position
	player.get_parent().add_child(w)
	Sfx.play("gravity", target.global_position)
	cooldown = cfg.cd * fuse_rate()
