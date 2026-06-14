class_name MineNode
extends Node2D
## Armed mine: explodes when an enemy comes close, damaging an area.

var damage := 6.0
var blast_radius := 100.0
var trigger_radius := 55.0  # Area
var arm := 0.4  # arming delay so it doesn't pop the instant it drops
var life := 12.0  # Duration: stays armed this long before going inert
var spawn_missiles := 0  # fused Cluster Mine launches this many homing rockets
var fire_dps := 0.0      # fused Napalm Mine leaves a burning pool on blast
var fire_radius := 0.0
var fire_dur := 2.0
var t := 0.0


func _ready() -> void:
	add_to_group("mines")
	z_index = -1  # ground object, under enemies


func _physics_process(delta: float) -> void:
	t += delta
	arm -= delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	queue_redraw()
	if arm > 0.0:
		return
	for e in Main.instance.all_enemies():
		if global_position.distance_to(e.global_position) <= trigger_radius + e.radius:
			_explode()
			return


func _explode() -> void:
	var fx := RingFx.new()
	fx.position = global_position
	fx.radius = 20.0
	fx.max_radius = blast_radius
	fx.life = 0.3
	fx.color = Color(1.0, 0.55, 0.2)
	get_parent().add_child(fx)
	Sfx.play("boom", global_position, -4.0)
	for e in Main.instance.all_enemies():
		if global_position.distance_to(e.global_position) <= blast_radius + e.radius:
			e.take_hit(damage, global_position)
	for i in spawn_missiles:
		var m := MissileProj.new()
		m.damage = damage * 0.5
		m.splash = blast_radius * 0.5
		m.velocity = Vector2.from_angle(TAU * i / maxi(spawn_missiles, 1)) * 260.0
		m.position = global_position
		get_parent().add_child(m)
	if fire_dps > 0.0:
		var pud := VenomPuddle.new()
		pud.radius = fire_radius
		pud.damage = fire_dps
		pud.max_life = fire_dur
		pud.life = fire_dur
		pud.fiery = true
		pud.burn_dps = fire_dps
		pud.burn_dur = 1.0
		pud.position = global_position
		get_parent().add_child(pud)
	queue_free()


func _draw() -> void:
	var blink := fmod(t, 0.8) < 0.4
	draw_circle(Vector2.ZERO, 7.0, Color(0.35, 0.35, 0.4))
	draw_circle(Vector2.ZERO, 2.5, Color(1.0, 0.25, 0.2) if blink else Color(0.5, 0.15, 0.1))
