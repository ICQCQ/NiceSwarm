# --- laser + mines: the blast leaves a spinning laser array behind -----------
class_name FusBeamMine
extends FusMineBase

func _init() -> void:
	weapon_id = "fus_beammine"
	display_name = "Beam Mine"
func _load(m: MineNode) -> void:
	m.beam_spokes = level  # one spinning "hand" per Beam Mine level (1-7)
	m.beam_dmg = cfg.beam_dmg * fuse_damage() * (1.0 + cfg.beam_growth * level)
	m.beam_len = (cfg.beam_len + cfg.beam_len_per_count * count_level()) * fuse_area()
	m.beam_spin = cfg.beam_spin / fuse_rate()  # Haste spins the array faster
	m.beam_rate = fuse_rate()       # Haste also shortens the per-enemy re-hit cooldown
	m.beam_spin_life = cfg.beam_spin_life * fuse_duration()
	m.beam_burn_dur = cfg.beam_burn_dur * fuse_duration()
