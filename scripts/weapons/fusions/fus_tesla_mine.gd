# --- lightning + mines: mines chain lightning outward on blast ---------------
class_name FusTeslaMine
extends FusMineBase

func _init() -> void:
	weapon_id = "fus_teslamine"
	display_name = "Tesla Mine"
func _load(m: MineNode) -> void:
	m.chain_count = cfg.chain_count_base + count_level()
	m.chain_dmg = cfg.chain_dmg * fuse_damage() * (1.0 + cfg.chain_growth * level)
	m.chain_range = cfg.chain_range * fuse_area()
