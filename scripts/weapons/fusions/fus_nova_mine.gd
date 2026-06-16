# --- mines + nova: mines pulse a second energy blast on detonation -----------
class_name FusNovaMine
extends FusMineBase

func _init() -> void:
	weapon_id = "fus_novamine"
	display_name = "Nova Mine"
func _load(m: MineNode) -> void:
	m.nova_radius = (180.0 + 25.0 * level) * fuse_area()
	m.nova_dmg = 2.6 * fuse_damage() * (1.0 + 0.4 * level)
	m.nova_push = 80.0 * fuse_area()
