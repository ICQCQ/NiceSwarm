# --- flame + venom: an eerie field that chip-damages and burns everyone -----
# inside, marking them -- marked enemies take extra damage, slows on them ----
# bite twice as hard, and their burn can't fade while they stay marked -------
class_name FusPurgatory
extends WeaponBase

var drop := 0.0
func _init() -> void:
	weapon_id = "fus_purgatory"
	display_name = "Purgatory"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	drop -= delta
	if drop > 0.0:
		return
	drop = cfg.cd * fuse_rate()  # Haste: cooldown between fields
	var p := PurgatoryField.new()
	p.source_pid = player.peer_id
	p.source_weapon = self
	p.radius = (cfg.radius + cfg.radius_per_level * (level - 1)) * fuse_area()
	p.damage = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	p.max_life = cfg.life * fuse_duration()  # Duration: field lifetime
	p.life = p.max_life
	p.burn_dps = cfg.burn_dps_ratio * fuse_damage()
	p.burn_dur = cfg.burn_dur * fuse_duration()
	p.vuln_stat_mult = player.damage_mult  # Power: deepens the mark's base bonus (AfflictConfig.deepened)
	p.vuln_dur = cfg.vuln_dur * fuse_duration()  # Duration: how long the mark lingers
	p.position = player.global_position
	player.get_parent().add_child(p)
	Sfx.play("venom", player.global_position)
