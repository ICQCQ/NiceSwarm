class_name XpGem
extends Node2D
## Dropped by enemies; flies to the nearest living player in pickup range.
## Host-authoritative: puppets on clients only mirror synced positions.

signal collected(value: int)

var value := 1
var pull_speed := 0.0
var force_pull := false  # set by the magnet pickup

var main_ref: Node
var puppet := false
var net_id := 0
var net_target := Vector2.ZERO


func _ready() -> void:
	add_to_group("gems")
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
	if force_pull or d <= p.pickup_range:
		pull_speed = minf(pull_speed + 1400.0 * delta, 760.0)
		global_position = global_position.move_toward(p.global_position, pull_speed * delta)
	if d <= 22.0:
		collected.emit(value)
		queue_free()


func _draw() -> void:
	# Condensed gems (value funneled in at the gem cap) read as a big red orb that grows
	# with value, so a pile of XP is visually distinct from a normal green drop.
	if value >= GameConfig.GEM_CONDENSED_THRESHOLD:
		var cr := clampf(10.0 + float(value) * 0.12, 10.0, 28.0)
		draw_circle(Vector2.ZERO, cr, Color(1.0, 0.3, 0.3))
		draw_circle(Vector2.ZERO, cr * 0.45, Color(1.0, 0.8, 0.55))
		return
	var r := 5.0 if value <= 1 else 8.0
	draw_circle(Vector2.ZERO, r, Color(0.45, 1.0, 0.55))
