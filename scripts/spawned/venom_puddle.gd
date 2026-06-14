class_name VenomPuddle
extends Node2D
## Toxic ground puddle: damages enemies standing in it, fades out.

var radius := 45.0
var source_pid := -1  # scoreboard: which player owns this
var damage := 0.8   # per tick
var max_life := 3.0
var life := 3.0
var burn_dps := 0.0  # fused Toxic Pyre: ignites enemies in the puddle
var burn_dur := 0.0
var fiery := false   # draw orange instead of green
var freeze_slow := 0.0  # >0: slow enemies in puddle (Frostbite); duration scales with damage
var freeze_dur := 0.0
var icy := false     # draw blue-green instead of green
var tick := 0.0
var redraw_tick := 0.0


func _ready() -> void:
	z_index = -1
	queue_redraw()


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	# Fade is slow (3s+); redrawing at 10Hz instead of every physics frame
	# is visually identical but cuts draw calls ~6x when many puddles overlap.
	redraw_tick -= delta
	if redraw_tick <= 0.0:
		redraw_tick = 0.1
		queue_redraw()
	tick -= delta
	if tick > 0.0:
		return
	tick = 0.4
	for e in EnemyGrid.near(global_position, radius):
		if global_position.distance_to(e.global_position) <= radius + e.radius:
			e.take_hit(damage, null, Enemy.DMG_PHYS, source_pid)
			if burn_dps > 0.0:
				e.apply_burn(burn_dps, burn_dur)
			if freeze_slow > 0.0:
				e.apply_slow(freeze_slow, freeze_dur)


func _draw() -> void:
	var a := clampf(life / max_life, 0.0, 1.0)
	var base := Color(1.0, 0.5, 0.15) if fiery else (Color(0.3, 0.75, 0.9) if icy else Color(0.3, 0.85, 0.3))
	var spot := Color(1.0, 0.75, 0.2) if fiery else (Color(0.55, 0.9, 1.0) if icy else Color(0.4, 1.0, 0.4))
	draw_circle(Vector2.ZERO, radius, Color(base.r, base.g, base.b, 0.22 * a))
	draw_circle(Vector2(radius * 0.3, -radius * 0.2), radius * 0.25, Color(spot.r, spot.g, spot.b, 0.3 * a))
	draw_circle(Vector2(-radius * 0.35, radius * 0.25), radius * 0.18, Color(spot.r, spot.g, spot.b, 0.3 * a))
