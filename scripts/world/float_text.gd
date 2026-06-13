class_name FloatText
extends Node2D
## Floating, fading text — used for damage numbers.

const LIFE := 0.6

var text := ""
var color := Color(1.0, 0.95, 0.8)
var t := 0.0


func _process(delta: float) -> void:
	t += delta
	position.y -= 42.0 * delta
	if t >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var c := color
	c.a = 1.0 - t / LIFE
	draw_string(ThemeDB.fallback_font, Vector2(-30.0, 0.0), text,
		HORIZONTAL_ALIGNMENT_CENTER, 60.0, 15, c)
