class_name WeaponMissiles
extends WeaponBase
## Launches a salvo of homing missiles in random directions; they seek targets.

var cooldown := 1.2


func _init() -> void:
	weapon_id = "missiles"
	display_name = "Missiles"


func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	if player.nearest_enemy(800.0) == null:
		cooldown = 0.2
		return
	var count := 1 + level
	for i in count:
		var m := MissileProj.new()
		m.source_pid = player.peer_id
		m.damage = WeaponConfig.BASE.missiles.dmg * player.damage_mult * (1.0 + WeaponConfig.BASE.missiles.growth * (level - 1))
		m.splash = 70.0 * player.area_mult
		m.life = 4.0 * player.duration_mult
		m.velocity = Vector2.from_angle(randf() * TAU) * 300.0
		m.position = player.global_position
		player.get_parent().add_child(m)
	Sfx.play("missile", player.global_position)
	cooldown = WeaponConfig.BASE.missiles.cd * player.rate_mult
