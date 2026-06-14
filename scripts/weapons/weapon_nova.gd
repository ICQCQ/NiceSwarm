class_name WeaponNova
extends WeaponBase
## Periodic blast damaging everything around the player. Level = radius + damage.

var cooldown := 1.5


func _init() -> void:
	weapon_id = "nova"
	display_name = "Nova Pulse"


func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	var radius := (130.0 + 30.0 * (level - 1)) * player.area_mult
	var dmg := WeaponConfig.BASE.nova.dmg * player.damage_mult * (1.0 + WeaponConfig.BASE.nova.growth * (level - 1))
	var hit_any := false
	for e in Main.instance.all_enemies():
		if global_position.distance_to(e.global_position) <= radius + e.radius:
			e.take_hit(dmg, global_position, Enemy.DMG_ENERGY, player.peer_id)
			ignite(e, dmg)
			hit_any = true
	if hit_any:
		cooldown = WeaponConfig.BASE.nova.cd * player.rate_mult
		var fx := RingFx.new()
		fx.position = global_position
		fx.radius = 25.0
		fx.max_radius = radius
		fx.life = 0.4
		fx.color = Color(0.55, 0.5, 1.0)
		player.get_parent().add_child(fx)
		Sfx.play("nova", global_position)
	else:
		cooldown = 0.25  # nothing in range, retry soon
