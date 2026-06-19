# --- frost + gravity ---------------------------------------------------------
class_name FusGlacier
extends WeaponBase

var cooldown := 2.8
func _init() -> void:
	weapon_id = "fus_glacier"
	display_name = "Glacier"
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
	var w := GlacierField.new()
	w.source_pid = player.peer_id
	w.source_weapon = self
	w.radius = (cfg.radius + cfg.radius_per_count * (count_level() - 1)) * fuse_area()
	w.damage = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))  # re-anchored: Lv1 ≈ two max-level base weapons
	w.pull = cfg.pull
	w.life = cfg.life * fuse_duration()
	# Haste both speeds up the wave cadence and deepens the slow (lower fuse_rate -> smaller
	# slow_mult -> a harder slow), so Haste investment reads as "the ice bites harder and faster".
	w.slow_mult = cfg.slow_mult_base * fuse_rate()
	w.wave_interval = cfg.wave_interval * fuse_rate()
	w.freeze_wave_threshold = cfg.freeze_wave_threshold
	w.freeze_dur = cfg.freeze_dur_base * fuse_duration()
	w.position = target.global_position
	player.get_parent().add_child(w)
	Sfx.play("frost", target.global_position)
	cooldown = cfg.cd * fuse_rate()
