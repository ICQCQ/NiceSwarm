class_name Pickup
extends Node2D
## Dropped item: heart (heal), bomb (screen blast), magnet (vacuum gems),
## chest (free pick for the whole team). Host-authoritative; effects are
## applied by main.gd via the signal. Puppets on clients mirror position.

signal taken(kind: String, by: Node2D)

var kind := "heart"
var pull_speed := 0.0

var main_ref: Node
var puppet := false
var net_id := 0
var net_target := Vector2.ZERO


func _ready() -> void:
	net_target = global_position


func _process(delta: float) -> void:
	if puppet:
		global_position = global_position.lerp(net_target, minf(10.0 * delta, 1.0))
		return
	if main_ref == null:
		return
	var p: Node2D = main_ref.nearest_alive_player(global_position)
	if p == null:
		return
	var d := global_position.distance_to(p.global_position)
	if d <= p.pickup_range:
		pull_speed = minf(pull_speed + 1200.0 * delta, 520.0)
		global_position = global_position.move_toward(p.global_position, pull_speed * delta)
	if d <= 24.0:
		taken.emit(kind, p)
		queue_free()


func _draw() -> void:
	match kind:
		"heart":
			draw_circle(Vector2.ZERO, 9.0, Color(0.95, 0.3, 0.4))
			draw_rect(Rect2(-5.0, -1.5, 10.0, 3.0), Color.WHITE)
			draw_rect(Rect2(-1.5, -5.0, 3.0, 10.0), Color.WHITE)
		"bomb":
			draw_circle(Vector2.ZERO, 9.0, Color(0.25, 0.25, 0.3))
			draw_line(Vector2(0.0, -8.0), Vector2(5.0, -14.0), Color(1.0, 0.6, 0.2), 2.0)
			draw_circle(Vector2(5.0, -14.0), 2.5, Color(1.0, 0.85, 0.3))
		"magnet":
			draw_arc(Vector2.ZERO, 8.0, PI, TAU, 16, Color(0.35, 0.6, 1.0), 4.0)
			draw_rect(Rect2(-10.0, 0.0, 4.0, 8.0), Color(0.9, 0.9, 0.95))
			draw_rect(Rect2(6.0, 0.0, 4.0, 8.0), Color(0.9, 0.9, 0.95))
		"chest":
			draw_rect(Rect2(-11.0, -8.0, 22.0, 16.0), Color(0.85, 0.62, 0.2))
			draw_rect(Rect2(-11.0, -8.0, 22.0, 5.0), Color(0.55, 0.38, 0.1))
			draw_circle(Vector2(0.0, 1.0), 2.5, Color(0.3, 0.2, 0.05))
