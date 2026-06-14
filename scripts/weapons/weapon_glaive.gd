class_name WeaponGlaive
extends WeaponBase
## Boomerang glaive thrower. Lv3/Lv5 add extra glaives in a fan.

var cooldown := 0.8


func _init() -> void:
	weapon_id = "glaive"
	display_name = "Glaive"


func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	var target := player.nearest_enemy(650.0)
	if target == null:
		cooldown = 0.1
		return
	var count := 1
	if level >= 2:
		count += 1
	if level >= 3:
		count += level - (3 - 1)
	var base := (target.global_position - player.global_position).normalized()
	for i in count:
		var g := GlaiveProj.new()
		g.source_pid = player.peer_id
		g.player = player
		g.velocity = base.rotated(deg_to_rad(25.0) * (i - (count - 1) / 2.0)) * 430.0
		g.damage = WeaponConfig.BASE.glaive.dmg * player.damage_mult * (1.0 + WeaponConfig.BASE.glaive.growth * (level - 1))
		g.burn_dps = g.damage * 0.3
		g.hit_radius = 14.0 * player.area_mult
		g.position = player.global_position
		player.get_parent().add_child(g)
	Sfx.play("glaive", player.global_position)
	cooldown = WeaponConfig.BASE.glaive.cd * player.rate_mult
