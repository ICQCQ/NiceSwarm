# --- lightning + mines: mines chain lightning outward on blast ---------------
class_name FusTeslaMine
extends FusMineBase

func _init() -> void:
	weapon_id = "fus_teslamine"
	display_name = "Tesla Mine"
func _load(m: MineNode) -> void:
	m.chain_count = 2 + count_level()
	m.chain_dmg = 2.0 * fuse_damage() * (1.0 + 0.4 * level)
	m.chain_range = 220.0 * fuse_area()
