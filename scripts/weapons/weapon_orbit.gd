class_name WeaponOrbit
extends WeaponBase
## Blades orbiting the player; damage enemies they touch. Level = blades - 1.

const BLADE_R := 10.0
const ORBIT_R := 75.0
const SPIN_SPEED := 3.2
const HIT_COOLDOWN := 0.45  # per enemy

var angle := 0.0
var hit_cd := {}  # enemy instance id -> seconds until it can be hit again


func _init() -> void:
	weapon_id = "orbit"
	display_name = "Orbit Blades"


func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		queue_redraw()
		return
	angle = fmod(angle + SPIN_SPEED / player.rate_mult * delta, TAU)  # Haste spins faster
	queue_redraw()

	var expired := []
	for k in hit_cd:
		hit_cd[k] -= delta
		if hit_cd[k] <= 0.0:
			expired.append(k)
	for k in expired:
		hit_cd.erase(k)

	var n := level + 1
	var dmg := WeaponConfig.BASE.orbit.dmg * player.damage_mult * (1.0 + WeaponConfig.BASE.orbit.growth * (level - 1))
	var orbit_r := ORBIT_R * player.area_mult
	var blade_r := BLADE_R * player.area_mult
	for e in Main.instance.enemies_in_radius(global_position, orbit_r + blade_r + 64.0):
		if hit_cd.has(e.get_instance_id()):
			continue
		for i in n:
			var blade_pos: Vector2 = global_position \
				+ Vector2.from_angle(angle + TAU * float(i) / n) * orbit_r
			if blade_pos.distance_to(e.global_position) <= blade_r + e.radius:
				e.take_hit(dmg, blade_pos, Enemy.DMG_PHYS, player.peer_id)
				ignite(e, dmg)
				hit_cd[e.get_instance_id()] = HIT_COOLDOWN * player.rate_mult
				Sfx.play("orbit", blade_pos)
				break


func _draw() -> void:
	if player == null or player.downed:
		return
	var n := level + 1
	var orbit_r := ORBIT_R * player.area_mult
	var blade_r := BLADE_R * player.area_mult
	for i in n:
		var p := Vector2.from_angle(angle + TAU * float(i) / n) * orbit_r
		draw_circle(p, blade_r, Color(0.7, 0.9, 1.0))
		draw_circle(p, blade_r * 0.5, Color(0.2, 0.4, 0.7))
