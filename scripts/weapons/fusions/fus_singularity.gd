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
	var target := player.nearest_enemy(700.0)
	if target == null:
		cooldown = 0.2
		return
	var w := GravityWell.new()
	w.source_pid = player.peer_id
	w.source_weapon = self
	w.radius = (212.0 + 8.0 * (count_level() - 1)) * fuse_area()
	w.damage = 3.0 * fuse_damage() * (1.0 + GameConfig.FUSION_LEVEL_GROWTH * (level - 1))  # re-anchored: Lv1 ≈ two max-level base weapons
	w.pull = 210.0
	w.life = 2.5 * fuse_duration()
	w.detonate_damage = 8.9 * fuse_damage() * (1.0 + GameConfig.FUSION_LEVEL_GROWTH * (level - 1))  # re-anchored: nova @L7 (13.35 eff)
	w.push_strength = 70.0 * fuse_area()  # meatier collapse shockwave
	w.position = target.global_position
	player.get_parent().add_child(w)
	Sfx.play("gravity", target.global_position)
	cooldown = 5.5 * fuse_rate()
