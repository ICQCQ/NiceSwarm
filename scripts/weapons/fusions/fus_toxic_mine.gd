# --- mines + venom: mines leave a toxic pool on blast -------------------------
class_name FusToxicMine
extends FusMineBase

func _init() -> void:
	weapon_id = "fus_toxicmine"
	display_name = "Toxic Mine"
func _load(m: MineNode) -> void:
	m.venom_radius = (cfg.venom_radius + cfg.venom_radius_per_count * count_level()) * fuse_area()
	m.venom_dps = cfg.venom_dps * fuse_damage() * (1.0 + cfg.venom_growth * level)
	m.venom_dur = cfg.venom_dur * fuse_duration()
