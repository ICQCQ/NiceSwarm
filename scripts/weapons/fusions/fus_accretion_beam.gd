# --- gravity + laser: a vortex ringed by rotating energy beams ---------------
class_name FusAccretionBeam
extends WeaponBase

var cooldown := 3.0
func _init() -> void:
	weapon_id = "fus_accretion"
	display_name = "Accretion Beam"
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
	var r := (150.0 + 14.0 * (level - 1)) * fuse_area()
	var w := GravityWell.new()
	w.source_pid = player.peer_id
	w.source_weapon = self
	w.radius = r
	w.damage = 3.0 * fuse_damage() * (1.0 + GameConfig.FUSION_LEVEL_GROWTH * (level - 1))
	w.pull = 190.0
	w.life = 3.0 * fuse_duration()
	w.beam_spokes = 1 + count_level()
	w.beam_dmg = 3.0 * fuse_damage() * (1.0 + GameConfig.FUSION_LEVEL_GROWTH * (level - 1))
	w.beam_len = r
	w.beam_spin = 2.0 / fuse_rate()
	w.position = target.global_position
	player.get_parent().add_child(w)
	Sfx.play("laser", target.global_position)
	cooldown = 5.5 * fuse_rate()
