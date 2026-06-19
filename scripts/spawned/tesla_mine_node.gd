class_name TeslaMineNode
extends Node2D
## Tesla Mine: inert for its first `inert_period` (Duration scales how long) --
## enemy contact does nothing while inert. Once that period elapses it arms
## like a normal mine: the next enemy contact detonates it. Throughout both
## phases (and regardless of whether it ever gets touched) it projects a
## continuous shocking field: on a recurring per-mine cooldown (NOT every
## physics frame, so a handful of mines stay cheap regardless of swarm size)
## it zaps the nearest enemy in `chain_range` and the bolt chains to
## `chain_count` more nearby enemies, same pattern as Chain Lightning/turrets.
## It still has a normal mine lifespan (`life`) -- if never touched, it just
## fizzles out at the end like any other mine, no explosion.

var source_pid := -1
var source_weapon: WeaponBase
var owner_weapon_id := -1
var chain_count := 2
var chain_range := 220.0  # Area: reach for both the first zap and each chain hop
var dmg := 2.0
var shock_interval := 0.7  # Haste: recurring tick rate of the field, not per-frame
var life := 14.0  # Duration: still a normal mine lifespan
var inert_period := 4.0  # Duration: contact is harmless until this runs out
var blast_dmg := 0.0
var blast_radius := 100.0
var trigger_radius := 50.0
var t := 0.0
var _cooldown := 0.0
var _trigger: Area2D


func _ready() -> void:
	add_to_group("tesla_mines")
	z_index = -1
	_cooldown = randf() * shock_interval  # desync mines dropped on the same frame
	_trigger = Area2D.new()
	_trigger.collision_layer = 0
	_trigger.collision_mask = 2
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = trigger_radius
	cs.shape = circle
	_trigger.add_child(cs)
	_trigger.body_entered.connect(_on_body_entered)
	add_child(_trigger)


func _on_body_entered(body: Node) -> void:
	if inert_period <= 0.0 and body is Enemy:
		_explode()


func _physics_process(delta: float) -> void:
	t += delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	if inert_period > 0.0:
		inert_period -= delta
		if inert_period <= 0.0:
			inert_period = 0.0
			# just armed: catch any enemy already sitting inside the trigger
			for b in _trigger.get_overlapping_bodies():
				if b is Enemy:
					_explode()
					return
	_cooldown -= delta
	if _cooldown <= 0.0:
		_cooldown = shock_interval
		_shock()
	queue_redraw()


func _shock() -> void:
	var first: Node2D = null
	var bd := chain_range * chain_range
	for e in EnemyGrid.near(global_position, chain_range):
		var d: float = global_position.distance_squared_to(e.global_position)
		if d < bd:
			bd = d
			first = e
	if first == null:
		return
	var pts: Array = [global_position]
	var visited := {}
	var cur: Node2D = first
	var hops := chain_count + 1  # +1 for the initial zap itself
	while cur != null and hops > 0:
		visited[cur.get_instance_id()] = true
		pts.append(cur.global_position)
		if is_instance_valid(source_weapon):
			source_weapon.damage_dealt += dmg
		cur.take_hit(dmg, global_position, Enemy.DMG_ENERGY, source_pid)
		hops -= 1
		cur = _next_target(pts[pts.size() - 1], visited)
	var fx := LightningFx.new()
	fx.points = pts
	get_parent().add_child(fx)
	Sfx.play("lightning", global_position, -6.0)


func _next_target(from: Vector2, visited: Dictionary) -> Node2D:
	var best: Node2D = null
	var bd := chain_range * chain_range
	for e in EnemyGrid.near(from, chain_range):
		if visited.has(e.get_instance_id()):
			continue
		var d: float = from.distance_squared_to(e.global_position)
		if d < bd:
			bd = d
			best = e
	return best


func _explode() -> void:
	var fx := RingFx.new()
	fx.position = global_position
	fx.radius = 20.0
	fx.max_radius = blast_radius
	fx.life = 0.3
	fx.color = Color(0.5, 0.7, 1.0)
	get_parent().add_child(fx)
	Sfx.play("boom", global_position, -4.0)
	for e in EnemyGrid.near(global_position, blast_radius):
		if global_position.distance_to(e.global_position) <= blast_radius + e.radius:
			if is_instance_valid(source_weapon):
				source_weapon.damage_dealt += blast_dmg
			e.take_hit(blast_dmg, global_position, Enemy.DMG_ENERGY, source_pid)
	queue_free()


func _draw() -> void:
	var blink := fmod(t, 0.8) < 0.4
	var core: Color
	if inert_period > 0.0:
		core = Color(0.6, 0.75, 1.0) if blink else Color(0.25, 0.35, 0.55)
	else:
		core = Color(1.0, 0.35, 0.2) if blink else Color(0.5, 0.15, 0.1)
	draw_circle(Vector2.ZERO, 7.0, Color(0.35, 0.35, 0.4))
	draw_circle(Vector2.ZERO, 2.5, core)
	draw_arc(Vector2.ZERO, chain_range, 0.0, TAU, 32, Color(0.5, 0.7, 1.0, 0.08), 2.0)
