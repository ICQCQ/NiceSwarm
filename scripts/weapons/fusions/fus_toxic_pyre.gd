# --- flame + venom -----------------------------------------------------------
class_name FusToxicPyre
extends WeaponBase

var drop := 0.0
func _init() -> void:
	weapon_id = "fus_pyre"
	display_name = "Toxic Pyre"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	drop -= delta
	if drop > 0.0:
		return
	drop = cfg.cd * fuse_rate()
	var p := VenomPuddle.new()
	p.source_pid = player.peer_id
	p.source_weapon = self
	p.radius = (cfg.radius + cfg.radius_per_level * (level - 1)) * fuse_area()
	p.damage = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	p.max_life = cfg.life * fuse_duration()
	p.life = p.max_life
	p.fiery = true
	p.burn_dps = cfg.burn_dps_ratio * fuse_damage()
	p.burn_dur = cfg.burn_dur * fuse_duration()
	p.position = player.global_position
	player.get_parent().add_child(p)
	Sfx.play("venom", player.global_position)
