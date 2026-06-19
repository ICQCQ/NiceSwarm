# --- glaive + mines: mines burst into glaive shrapnel that shuttles back ----
# --- and forth from the blast point until it fades --------------------------
class_name FusShrapnelMine
extends FusMineBase

func _init() -> void:
	weapon_id = "fus_shrapnelmine"
	display_name = "Shrapnel Mine"
func _load(m: MineNode) -> void:
	m.shrapnel_count = cfg.shrapnel_count_base + count_level()
	m.shrapnel_dmg = cfg.shrapnel_dmg * fuse_damage() * (1.0 + cfg.shrapnel_growth * level)
	m.shrapnel_radius = cfg.shrapnel_radius * fuse_area()
	m.shrapnel_life = cfg.shrapnel_life * fuse_duration()
