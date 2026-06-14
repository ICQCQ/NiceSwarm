class_name WeaponGravity
extends WeaponBase
## Spawns a gravity well on the nearest enemy, dragging the swarm together.

var cooldown := 2.0


func _init() -> void:
	weapon_id = "gravity"
	display_name = "Gravity Well"


func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	var target := player.nearest_enemy(700.0)
	if target == null:
		cooldown = 0.2
		return
	var well := GravityWell.new()
	well.source_pid = player.peer_id
	well.radius = (160.0 + 15.0 * (level - 1)) * player.area_mult
	well.damage = WeaponConfig.BASE.gravity.dmg * player.damage_mult * (1.0 + WeaponConfig.BASE.gravity.growth * (level - 1))
	well.pull = 170.0 + 15.0 * (level - 1)
	well.life = 2.5 * player.duration_mult
	well.position = target.global_position
	player.get_parent().add_child(well)
	Sfx.play("gravity", target.global_position)
	cooldown = WeaponConfig.BASE.gravity.cd * player.rate_mult
