class_name SpinLaser
extends Node2D
## Stationary laser array left behind by an exploding Beam Mine: `spokes` rotating
## arms ("hands") pulse outward from the blast site for a short duration.

const HIT_COOLDOWN := 0.3  # per enemy, mirrors WeaponLaser

var spokes := 2
var dmg := 1.0
var length := 160.0
var spin := 2.2            # rad/s
var rate_mult := 1.0       # Haste: scales the per-enemy re-hit cooldown (lower = faster)
var life := 1.5
var burn_dur := 0.0
var source_pid := -1
var source_weapon: WeaponBase
var angle := 0.0
var hit_cd := {}


func _ready() -> void:
	z_index = -1
	angle = randf() * TAU


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	angle = fmod(angle + spin * delta, TAU)
	queue_redraw()

	var expired := []
	for k in hit_cd:
		hit_cd[k] -= delta
		if hit_cd[k] <= 0.0:
			expired.append(k)
	for k in expired:
		hit_cd.erase(k)

	for e in EnemyGrid.near(global_position, length):
		if hit_cd.has(e.get_instance_id()):
			continue
		var rel: Vector2 = e.global_position - global_position
		for s in spokes:
			var dir := Vector2.from_angle(angle + TAU * float(s) / spokes)
			var along := clampf(rel.dot(dir), 0.0, length)
			if (dir * along).distance_to(rel) <= 8.0 + e.radius:
				if is_instance_valid(source_weapon):
					source_weapon.damage_dealt += dmg
				e.take_hit(dmg, global_position + dir * along, Enemy.DMG_ENERGY, source_pid)
				if burn_dur > 0.0:
					e.apply_burn(dmg * 0.3, burn_dur)
				hit_cd[e.get_instance_id()] = HIT_COOLDOWN * rate_mult
				break


func _draw() -> void:
	var fade := clampf(life / 0.4, 0.0, 1.0)  # quick fade-out at the end
	for s in spokes:
		var dir := Vector2.from_angle(angle + TAU * float(s) / spokes)
		draw_line(Vector2.ZERO, dir * length, Color(1.0, 0.3, 0.4, 0.25 * fade), 9.0)
		draw_line(Vector2.ZERO, dir * length, Color(1.0, 0.5, 0.55, fade), 3.0)
