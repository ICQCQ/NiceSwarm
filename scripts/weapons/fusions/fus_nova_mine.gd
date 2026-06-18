# --- mines + nova: mines pulse a second energy blast on detonation -----------
class_name FusNovaMine
extends FusMineBase

func _init() -> void:
	weapon_id = "fus_novamine"
	display_name = "Nova Mine"
func _load(m: MineNode) -> void:
	m.nova_radius = (cfg.nova_radius + cfg.nova_radius_per_count * count_level()) * fuse_area()
	m.nova_dmg = cfg.nova_dmg * fuse_damage() * (1.0 + cfg.nova_growth * level)
	m.nova_push = cfg.nova_push * fuse_area()
