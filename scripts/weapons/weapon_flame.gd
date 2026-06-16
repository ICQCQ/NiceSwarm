class_name WeaponFlame
extends WeaponBase
## Flamethrower cone in the player's facing direction; rapid small ticks. Past Lv3
## the cone widens each level, so high levels catch more of the swarm, not just reach.

const TICK_TIME := 0.15
const HALF_ANGLE := 0.61  # ~35 degrees at Lv1-3
const WIDEN_PER_LEVEL := 0.12  # cone half-angle grows this fraction per level past Lv3
const BURN_STACK_MULT := 1.6  # signature: flame piles burn stacks on faster than other sources

var tick := 0.0


func _init() -> void:
	weapon_id = "flame"
	display_name = "Flame Cone"


## Cone half-angle: fixed up to Lv3, then widens with level (capped ~55 degrees).
func _half_angle() -> float:
	return HALF_ANGLE * (1.0 + WIDEN_PER_LEVEL * maxi(0, count_level() - 3))


func _physics_process(delta: float) -> void:
	queue_redraw()
	if player == null or player.downed:
		return
	tick -= delta
	if tick > 0.0:
		return
	tick = TICK_TIME * player.rate_mult
	var reach := (150.0 + 12.0 * (level - 1)) * player.area_mult
	var half := _half_angle()
	var dmg := WeaponConfig.BASE.flame.dmg * player.damage_mult * (1.0 + WeaponConfig.BASE.flame.growth * (level - 1))
	var hit_any := false
	# Broad-phase by reach (grid); +64 margin covers the largest enemy radius (38) so a
	# grazing hit at reach+e.radius is never dropped. The cone test below is unchanged.
	for e in Main.instance.enemies_in_radius(player.global_position, reach + 64.0):
		var to: Vector2 = e.global_position - player.global_position
		if to.length() <= reach + e.radius and absf(player.facing.angle_to(to)) <= half:
			damage_dealt += dmg
			e.take_hit(dmg, null, Enemy.DMG_FIRE, player.peer_id)
			ignite(e, dmg, BURN_STACK_MULT)
			hit_any = true
	if hit_any:
		Sfx.play("flame", player.global_position)


func _draw() -> void:
	if player == null or player.downed:
		return
	var reach := (150.0 + 12.0 * (level - 1)) * player.area_mult
	var half := _half_angle()
	var base_a := player.facing.angle()
	for i in 7:
		var ang := base_a + randf_range(-half * 0.8, half * 0.8)
		var dist := randf_range(reach * 0.25, reach)
		var p := Vector2.from_angle(ang) * dist
		var heat := 1.0 - dist / reach  # whiter near the nozzle
		draw_circle(p, randf_range(4.0, 11.0),
			Color(1.0, 0.45 + 0.4 * heat, 0.15, randf_range(0.3, 0.6)))
