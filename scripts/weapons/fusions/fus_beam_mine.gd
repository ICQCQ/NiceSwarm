# --- laser + mines: mines that link sustained laser beams to each other -----
class_name FusBeamMine
extends WeaponBase

var cooldown := 1.1
func _init() -> void:
	weapon_id = "fus_beammine"
	display_name = "Beam Mine"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	if owned_in_group("beam_mines") >= cfg.cap_base + count_level():
		cooldown = 0.2
		return
	var m := BeamMineNode.new()
	m.source_pid = player.peer_id
	m.source_weapon = self
	m.owner_weapon_id = get_instance_id()
	m.blast_dmg = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	m.blast_radius = (cfg.blast_radius + cfg.blast_radius_per_count * (count_level() - 1)) * fuse_area()
	m.link_dmg = cfg.link_dmg * fuse_damage() * (1.0 + cfg.link_growth * (level - 1))
	m.trigger_radius = cfg.trigger_radius * fuse_area()
	# Area widens how far a mine reaches to link up with its neighbors.
	m.link_range = (cfg.link_range + cfg.link_range_per_count * count_level()) * fuse_area()
	m.beam_width = cfg.beam_width * fuse_area()
	m.life = cfg.life * fuse_duration()
	m.inert_dur = cfg.inert_dur * fuse_duration()
	m.rate_mult = fuse_rate()
	m.position = player.global_position \
		+ Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 30.0))
	player.get_parent().add_child(m)
	Sfx.play("mine", player.global_position)
	cooldown = cfg.cd * fuse_rate()
