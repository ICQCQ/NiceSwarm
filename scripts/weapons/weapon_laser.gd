class_name WeaponLaser
extends WeaponBase
## Beam sweeping around the player; Lv4 adds a second, opposite beam.

const SPIN := 1.4
const HIT_COOLDOWN := 0.3  # per enemy

var angle := 0.0
var hit_cd := {}


func _init() -> void:
	weapon_id = "laser"
	display_name = "Sweep Laser"


func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		queue_redraw()
		return
	angle = fmod(angle + SPIN / player.rate_mult * delta, TAU)  # Haste sweeps faster
	queue_redraw()

	var expired := []
	for k in hit_cd:
		hit_cd[k] -= delta
		if hit_cd[k] <= 0.0:
			expired.append(k)
	for k in expired:
		hit_cd.erase(k)

	var beams := level
	var length := (240.0 + 30.0 * (level - 1)) * player.area_mult
	var dmg := WeaponConfig.BASE.laser.dmg * player.damage_mult * (1.0 + WeaponConfig.BASE.laser.growth * (level - 1))
	for e in Main.instance.all_enemies():
		if hit_cd.has(e.get_instance_id()):
			continue
		var rel: Vector2 = e.global_position - global_position
		for b in beams:
			var dir := Vector2.from_angle(angle + PI * b)
			var along := clampf(rel.dot(dir), 0.0, length)
			if (dir * along).distance_to(rel) <= 6.0 + e.radius:
				e.take_hit(dmg, global_position + dir * along, Enemy.DMG_ENERGY, player.peer_id)
				ignite(e, dmg)
				hit_cd[e.get_instance_id()] = HIT_COOLDOWN * player.rate_mult
				Sfx.play("laser", e.global_position)
				break


func _draw() -> void:
	if player == null or player.downed:
		return
	var beams := 2 if level >= 3 else 1
	var length := (240.0 + 30.0 * (level - 1)) * player.area_mult
	for b in beams:
		var dir := Vector2.from_angle(angle + PI * b)
		draw_line(Vector2.ZERO, dir * length, Color(1.0, 0.3, 0.4, 0.25), 9.0)
		draw_line(Vector2.ZERO, dir * length, Color(1.0, 0.5, 0.55), 3.0)
