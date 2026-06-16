class_name WeaponLaser
extends WeaponBase
## Beams sweeping around the player. Beam count grows 1 -> 4 with level (evenly
## spread), so high levels widen coverage instead of only adding damage/length.


## Beams spread evenly around the player and scale with level (capped at 4).
## A real above-Lv3 upgrade: the old code computed count_level() beams but
## offset them by PI*b, collapsing every beam onto the same 2 opposite lines.
func _beam_count() -> int:
	return mini(1 + (count_level() - 1) / 2, 4)  # Lv1-2:1, Lv3-4:2, Lv5-6:3, Lv7:4

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

	var beams := _beam_count()
	var length := (240.0 + 30.0 * (level - 1)) * player.area_mult
	var dmg := WeaponConfig.BASE.laser.dmg * player.damage_mult * (1.0 + WeaponConfig.BASE.laser.growth * (level - 1))
	# Broad-phase by beam length (grid); +64 margin covers the largest enemy radius (38) so
	# an enemy grazed at the beam tip is never dropped. The per-beam line test is unchanged.
	for e in Main.instance.enemies_in_radius(global_position, length + 64.0):
		if hit_cd.has(e.get_instance_id()):
			continue
		var rel: Vector2 = e.global_position - global_position
		for b in beams:
			var dir := Vector2.from_angle(angle + TAU * float(b) / beams)
			var along := clampf(rel.dot(dir), 0.0, length)
			if (dir * along).distance_to(rel) <= 6.0 + e.radius:
				damage_dealt += dmg
				e.take_hit(dmg, global_position + dir * along, Enemy.DMG_ENERGY, player.peer_id)
				ignite(e, dmg)
				hit_cd[e.get_instance_id()] = HIT_COOLDOWN * player.rate_mult
				Sfx.play("laser", e.global_position)
				break


func _draw() -> void:
	if player == null or player.downed:
		return
	var beams := _beam_count()
	var length := (240.0 + 30.0 * (level - 1)) * player.area_mult
	for b in beams:
		var dir := Vector2.from_angle(angle + TAU * float(b) / beams)
		draw_line(Vector2.ZERO, dir * length, Color(1.0, 0.3, 0.4, 0.25), 9.0)
		draw_line(Vector2.ZERO, dir * length, Color(1.0, 0.5, 0.55), 3.0)
