class_name BombingField
extends Node2D
## Carpet Bombing target zone: a marked ground area that periodically calls in a
## missile aimed at a random point inside itself (not at any enemy) for its lifetime.

var radius := 140.0
var life := 4.0
var source_pid := -1  # scoreboard: which player owns this
var source_weapon: WeaponBase
var player_ref: Player  # missiles launch from the player's current position
var missile_interval := 0.55  # Haste: time between missile waves
var missile_count := 1        # missiles per wave; grows with weapon level
var missile_dmg := 5.0
var missile_splash := 55.0
var missile_life := 3.0
var timer := 0.0


func _ready() -> void:
	add_to_group("bombing_fields")
	z_index = -1


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	queue_redraw()
	timer -= delta
	if timer <= 0.0:
		timer = missile_interval
		for i in missile_count:
			_fire_missile()


func _fire_missile() -> void:
	if player_ref == null or not is_instance_valid(player_ref):
		return
	var ang := randf() * TAU
	var dist := sqrt(randf()) * radius  # uniform over the disc, not biased to the center
	var dest := global_position + Vector2.from_angle(ang) * dist
	var m := MissileProj.new()
	m.source_pid = source_pid
	m.source_weapon = source_weapon
	m.damage = missile_dmg
	m.splash = missile_splash
	m.life = missile_life
	m.use_point_target = true
	m.target_point = dest
	m.position = player_ref.global_position
	m.velocity = (dest - m.position).normalized() * 320.0
	player_ref.get_parent().add_child(m)
	Sfx.play("missile", player_ref.global_position, -6.0)


func _draw() -> void:
	var a := clampf(life / 0.5, 0.0, 1.0)  # quick fade-out at the end
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, Color(1.0, 0.55, 0.2, 0.45 * a), 2.0)
	draw_line(Vector2(-14.0, 0.0), Vector2(14.0, 0.0), Color(1.0, 0.55, 0.2, 0.85 * a), 2.0)
	draw_line(Vector2(0.0, -14.0), Vector2(0.0, 14.0), Color(1.0, 0.55, 0.2, 0.85 * a), 2.0)
	draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.35, 0.15, 0.9 * a))
