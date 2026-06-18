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
	var target := player.nearest_enemy(cfg.range)
	if target == null:
		cooldown = 0.2
		return
	var r: float = (cfg.radius_base + cfg.radius_per_level * (level - 1)) * fuse_area()
	var w := GravityWell.new()
	w.source_pid = player.peer_id
	w.source_weapon = self
	w.radius = r
	w.damage = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	w.pull = cfg.pull
	w.life = cfg.life * fuse_duration()
	w.beam_spokes = cfg.spokes_base + count_level()
	w.beam_dmg = cfg.beam_dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	w.beam_len = r
	w.beam_spin = cfg.beam_spin / fuse_rate()
	w.position = target.global_position
	player.get_parent().add_child(w)
	Sfx.play("laser", target.global_position)
	cooldown = cfg.cd * fuse_rate()
