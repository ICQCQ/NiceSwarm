class_name WeaponFused
extends WeaponBase
## Fusion of two maxed attacks living in ONE weapon slot. The component
## weapons keep firing as child nodes; each fusion level-up raises every
## component's level by one (formulas scale past 5), so fused parts keep
## growing. A level-5 fusion can be merged again for deeper layers.

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


func level_up() -> void:
	level += 1
	for c in components:
		c.level += 1
