class_name WeaponMines
extends WeaponBase
## Drops proximity mines at the player's position, up to a cap.

var cooldown := 1.0


func _init() -> void:
	weapon_id = "mines"
	display_name = "Mines"


func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	if get_tree().get_nodes_in_group("mines").size() >= 3 + level:
		cooldown = 0.2
		return
	var m := MineNode.new()
	m.source_pid = player.peer_id
	m.damage = WeaponConfig.BASE.mines.dmg * player.damage_mult * (1.0 + WeaponConfig.BASE.mines.growth * (level - 1))
	m.blast_radius = (100.0 + 15.0 * (level - 1)) * player.area_mult
	m.trigger_radius = 55.0 * player.area_mult
	m.life = 12.0 * player.duration_mult
	m.position = player.global_position \
		+ Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 30.0))
	player.get_parent().add_child(m)
	Sfx.play("mine", player.global_position)
	cooldown = WeaponConfig.BASE.mines.cd * player.rate_mult
