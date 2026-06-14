class_name VenomPuddle
extends Node2D
## Toxic ground puddle: damages enemies standing in it, fades out.

var radius := 45.0
var damage := 0.8   # per tick
var max_life := 3.0
var life := 3.0
var burn_dps := 0.0  # fused Toxic Pyre: ignites enemies in the puddle
var burn_dur := 0.0
var fiery := false   # draw orange instead of green
var tick := 0.0


func _ready() -> void:
	z_index = -1


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	queue_redraw()
	tick -= delta
	if tick > 0.0:
		return
	tick = 0.4
	for e in Main.instance.all_enemies():
		if global_position.distance_to(e.global_position) <= radius + e.radius:
			e.take_hit(damage)
			if burn_dps > 0.0:
				e.apply_burn(burn_dps, burn_dur)


func _draw() -> void:
	var a := clampf(life / max_life, 0.0, 1.0)
	var base := Color(1.0, 0.5, 0.15) if fiery else Color(0.3, 0.85, 0.3)
	var spot := Color(1.0, 0.75, 0.2) if fiery else Color(0.4, 1.0, 0.4)
	draw_circle(Vector2.ZERO, radius, Color(base.r, base.g, base.b, 0.22 * a))
	draw_circle(Vector2(radius * 0.3, -radius * 0.2), radius * 0.25, Color(spot.r, spot.g, spot.b, 0.3 * a))
	draw_circle(Vector2(-radius * 0.35, radius * 0.25), radius * 0.18, Color(spot.r, spot.g, spot.b, 0.3 * a))
