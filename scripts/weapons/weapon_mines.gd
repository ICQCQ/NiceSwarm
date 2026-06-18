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
	if owned_in_group("mines") >= cfg.cap_base + count_level():  # per-weapon cap, not a shared global count
		cooldown = 0.2
		return
	var m := MineNode.new()
	m.source_pid = player.peer_id
	m.source_weapon = self
	m.owner_weapon_id = get_instance_id()
	m.damage = cfg.dmg * player.damage_mult * (1.0 + cfg.growth * (level - 1))
	m.blast_radius = (cfg.blast_radius_base + cfg.blast_radius_per_level * (level - 1)) * player.area_mult
	m.trigger_radius = cfg.trigger_radius * player.area_mult
	m.life = cfg.life * player.duration_mult
	m.position = player.global_position \
		+ Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 30.0))
	player.get_parent().add_child(m)
	Sfx.play("mine", player.global_position)
	cooldown = cfg.cd * player.rate_mult
