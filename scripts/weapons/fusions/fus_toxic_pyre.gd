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
	drop = 0.3 * fuse_rate()
	var p := VenomPuddle.new()
	p.source_pid = player.peer_id
	p.source_weapon = self
	p.radius = (55.0 + 6.0 * (level - 1)) * fuse_area()
	p.damage = 1.0 * fuse_damage() * (1.0 + 0.4 * (level - 1))
	p.max_life = 3.0 * fuse_duration()
	p.life = p.max_life
	p.fiery = true
	p.burn_dps = 0.8 * fuse_damage()
	p.burn_dur = 1.2 * fuse_duration()
	p.position = player.global_position
	player.get_parent().add_child(p)
	Sfx.play("venom", player.global_position)
