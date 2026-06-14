class_name WeaponTurret
extends WeaponBase
## Deploys sentry turrets where the player stands; Lv3 allows two at once,
## and each level beyond 3 allows one more.

var cooldown := 1.5


func _init() -> void:
	weapon_id = "turret"
	display_name = "Sentry Turret"


func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	var max_turrets := 1 if level < 3 else level - 1  # Lv1-2: one, Lv3: two, +1 per level beyond
	var mine := 0
	for tn in get_tree().get_nodes_in_group("turrets"):
		if tn.owner_weapon_id == get_instance_id():
			mine += 1
	if mine >= max_turrets:
		cooldown = 0.3
		return
	var t := TurretNode.new()
	t.owner_weapon_id = get_instance_id()
	t.source_pid = player.peer_id
	t.life = (5.0 + 0.5 * level) * player.duration_mult
	t.damage = WeaponConfig.BASE.turret.dmg * player.damage_mult * (1.0 + WeaponConfig.BASE.turret.growth * (level - 1))
	t.target_range = 480.0 * player.area_mult
	t.proj_radius = 5.0 * player.area_mult
	t.fire_mult = player.rate_mult
	t.position = player.global_position
	player.get_parent().add_child(t)
	Sfx.play("turret_deploy", player.global_position)
	cooldown = WeaponConfig.BASE.turret.cd * player.rate_mult
