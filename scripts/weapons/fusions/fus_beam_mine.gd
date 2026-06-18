# --- laser + mines: the blast leaves a spinning laser array behind -----------
class_name FusBeamMine
extends FusMineBase

func _init() -> void:
	weapon_id = "fus_beammine"
	display_name = "Beam Mine"
func _load(m: MineNode) -> void:
	m.beam_spokes = level  # one spinning "hand" per Beam Mine level (1-7)
	m.beam_dmg = 2.4 * fuse_damage() * (1.0 + GameConfig.FUSION_LEVEL_GROWTH * level)
	m.beam_len = (170.0 + 16.0 * count_level()) * fuse_area()
	m.beam_spin = 2.4 / fuse_rate()  # Haste spins the array faster
	m.beam_rate = fuse_rate()       # Haste also shortens the per-enemy re-hit cooldown
	m.beam_spin_life = 1.4 * fuse_duration()
	m.beam_burn_dur = 1.0 * fuse_duration()
