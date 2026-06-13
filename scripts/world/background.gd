class_name Background
extends Node2D
## Draws the arena floor, grid, and border.

var arena := Rect2(-1200, -1200, 2400, 2400)


func _ready() -> void:
	z_index = -10  # ground effects (puddles, mines) sit at -1, above this


func _draw() -> void:
	draw_rect(arena, Color(0.07, 0.08, 0.12), true)
	var grid := Color(0.12, 0.14, 0.2)
	var step := 100.0
	var x := arena.position.x
	while x <= arena.end.x:
		draw_line(Vector2(x, arena.position.y), Vector2(x, arena.end.y), grid, 1.0)
		x += step
	var y := arena.position.y
	while y <= arena.end.y:
		draw_line(Vector2(arena.position.x, y), Vector2(arena.end.x, y), grid, 1.0)
		y += step
	draw_rect(arena, Color(0.5, 0.3, 0.6), false, 4.0)
