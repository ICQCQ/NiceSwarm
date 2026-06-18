class_name WeaponNova
extends WeaponBase
## Periodic blast damaging everything around the player. Level = radius + damage,
## and past Lv4 each pulse echoes: 1 extra shockwave at Lv5, 2 at Lv6, 3 at Lv7.

var cooldown := 1.5
var echoes_left := 0
var echo_cd := 0.0


func _init() -> void:
	weapon_id = "nova"
	display_name = "Nova Pulse"


func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	# Above-Lv4 kicker: drain queued echo pulses so high levels hit several times
	# per cooldown instead of only widening the radius.
	if echoes_left > 0:
		echo_cd -= delta
		if echo_cd <= 0.0:
			echoes_left -= 1
			echo_cd = cfg.echo_gap * player.rate_mult
			_blast()
	cooldown -= delta
	if cooldown > 0.0:
		return
	if _blast():
		cooldown = cfg.cd * player.rate_mult
		echoes_left = maxi(0, count_level() - 4)  # Lv5:1, Lv6:2, Lv7:3
		echo_cd = cfg.echo_gap * player.rate_mult
	else:
		cooldown = 0.25  # nothing in range, retry soon


## One shockwave: damages everything in the blast radius. Returns whether it hit.
func _blast() -> bool:
	var radius: float = (cfg.radius_base + cfg.radius_per_level * (level - 1)) * player.area_mult
	var dmg: float = cfg.dmg * player.damage_mult * (1.0 + cfg.growth * (level - 1))
	var hit_any := false
	# Broad-phase by blast radius (grid); +64 margin covers the largest enemy radius (38)
	# so a grazing hit at radius+e.radius is never dropped. The precise test is unchanged.
	for e in Main.instance.enemies_in_radius(global_position, radius + 64.0):
		if global_position.distance_to(e.global_position) <= radius + e.radius:
			damage_dealt += dmg
			e.take_hit(dmg, global_position, Enemy.DMG_ENERGY, player.peer_id)
			ignite(e, dmg)
			push(e, global_position)
			hit_any = true
	if hit_any:
		var fx := RingFx.new()
		fx.position = global_position
		fx.radius = 25.0
		fx.max_radius = radius
		fx.life = 0.4
		fx.color = Color(0.55, 0.5, 1.0)
		player.get_parent().add_child(fx)
		Sfx.play("nova", global_position)
	return hit_any
