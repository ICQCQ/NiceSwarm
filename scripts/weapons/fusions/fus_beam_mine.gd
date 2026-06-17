# --- laser + mines: mines pulse laser spokes outward on blast ----------------
class_name FusBeamMine
extends FusMineBase

func _init() -> void:
	weapon_id = "fus_beammine"
	display_name = "Beam Mine"
func _load(m: MineNode) -> void:
	m.beam_spokes = 2 + count_level()
	m.beam_dmg = 1.8 * fuse_damage() * (1.0 + 0.4 * level)
	m.beam_len = (180.0 + 20.0 * count_level()) * fuse_area()
	m.beam_burn_dur = 1.2 * fuse_duration()
