class_name WeaponFused
extends WeaponBase
## Fusion of two maxed attacks living in ONE weapon slot. The component weapons keep
## firing as child nodes. Leveling the amalgam buffs ALL of its components' stats by a
## flat +GameConfig.AMALGAM_STAT_PER_LEVEL per level via WeaponBase.fuse_pow — it does
## NOT raise each component's own level. Components were maxed (Lv7) when merged, so their
## base damage and spawn counts are already at cap; this flat boost is the amalgam's
## clean scaling axis. An amalgam is terminal — only base+base and signature+signature merge
## (see Fusions.can_merge).

var components: Array = []  # leaf WeaponBase nodes


func _init() -> void:
	weapon_id = "fused"
	display_name = "Fusion"


func setup(parts: Array) -> void:
	components = parts
	var names := []
	var ids := []
	for c in components:
		names.append(c.display_name)
		ids.append(c.weapon_id)
		if c.get_parent() != null:
			c.get_parent().remove_child(c)
		add_child(c)
	ids.sort()
	weapon_id = "fused_" + "_".join(ids)
	display_name = " + ".join(names)
	_apply_stat_boost()


func level_up() -> void:
	level += 1
	_apply_stat_boost()


## Push the current per-level stat multiplier onto every component (see class doc).
func _apply_stat_boost() -> void:
	var boost := 1.0 + GameConfig.AMALGAM_STAT_PER_LEVEL * (level - 1)
	for c in components:
		c.fuse_pow = boost
