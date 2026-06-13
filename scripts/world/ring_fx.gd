class_name RingFx
extends Node2D
## Short-lived expanding, fading ring (kill pops, nova blasts, bombs).

var radius := 20.0
var max_radius := 130.0
var color := Color(0.6, 0.8, 1.0)
var life := 0.35
var t := 0.0


func _process(delta: float) -> void:
	t += delta
	if t >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var p := t / life
	var c := color
	c.a = 1.0 - p
	draw_arc(Vector2.ZERO, lerpf(radius, max_radius, p), 0.0, TAU, 48, c, 3.0)
