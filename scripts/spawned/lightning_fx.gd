class_name LightningFx
extends Node2D
## Jagged fading polyline through the chain-lightning hit points.
## Added at world origin; points are global coordinates.

const LIFE := 0.22

var points: Array = []  # Vector2 hit positions, player first
var t := 0.0
var jagged := PackedVector2Array()


func _ready() -> void:
	for i in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var segs := 5
		for s in segs:
			var p := a.lerp(b, float(s) / segs)
			if s > 0:
				p += Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
			jagged.append(p)
	if points.size() > 0:
		jagged.append(points[points.size() - 1])


func _process(delta: float) -> void:
	t += delta
	if t >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	if jagged.size() < 2:
		return
	var fade := 1.0 - t / LIFE
	draw_polyline(jagged, Color(0.6, 0.7, 1.0, 0.4 * fade), 7.0)
	draw_polyline(jagged, Color(0.9, 0.95, 1.0, fade), 2.5)
