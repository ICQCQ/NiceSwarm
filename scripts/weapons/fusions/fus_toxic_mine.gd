# --- mines + venom: mines leave a toxic pool on blast -------------------------
class_name FusToxicMine
extends FusMineBase

func _init() -> void:
	weapon_id = "fus_toxicmine"
	display_name = "Toxic Mine"
func _load(m: MineNode) -> void:
	m.venom_radius = (80.0 + 10.0 * count_level()) * fuse_area()
	m.venom_dps = 1.0 * fuse_damage() * (1.0 + 0.4 * level)
	m.venom_dur = 3.0 * fuse_duration()
