# --- glaive + mines: mines burst into glaive shrapnel on blast --------------
class_name FusShrapnelMine
extends FusMineBase

func _init() -> void:
	weapon_id = "fus_shrapnelmine"
	display_name = "Shrapnel Mine"
func _load(m: MineNode) -> void:
	m.shrapnel_count = 3 + level
	m.shrapnel_dmg = 1.6 * fuse_damage() * (1.0 + 0.3 * level)
	m.shrapnel_radius = 12.0 * fuse_area()
