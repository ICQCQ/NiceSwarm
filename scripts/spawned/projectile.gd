class_name Projectile
extends Area2D
## Straight-flying bolt; dies on first enemy hit or after its lifetime.

var velocity := Vector2.ZERO
var source_pid := -1  # scoreboard: which player owns this
var damage := 1.0
var life := 1.6
var radius := 5.0  # scaled by the firing weapon's Area stat
var explode_radius := 0.0  # >0: burst into an AoE on hit (fused Plasma Burst)
var explode_damage := 0.0
var fire_puddle_radius := 0.0   # >0: drop a burning puddle on hit (Incendiary Rounds)
var fire_puddle_damage := 0.0
var fire_puddle_life := 0.0
var fire_puddle_burn_dps := 0.0
var fire_puddle_burn_dur := 0.0
var fire_puddle_source_pid := -1
var on_hit := Callable()        # optional: called(enemy, hit_pos, world) after damage
var color := Color(1.0, 0.92, 0.4)
var homing_turn := 0.0   # >0: fused Flak Battery curves toward the nearest enemy, rad/s
var homing_range := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	cs.shape = circle
	add_child(cs)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if homing_turn > 0.0:
		var target: Node2D = null
		var best_d := homing_range * homing_range
		for e in EnemyGrid.near(global_position, homing_range):
			var d: float = global_position.distance_squared_to(e.global_position)
			if d < best_d:
				best_d = d
				target = e
		if target != null:
			var desired: Vector2 = (target.global_position - global_position).normalized()
			var speed := velocity.length()
			var cur := velocity.normalized()
			var ang := cur.angle_to(desired)
			ang = clampf(ang, -homing_turn * delta, homing_turn * delta)
			velocity = cur.rotated(ang) * speed
	position += velocity * delta
	life -= delta
	if life <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body is Enemy:
		body.take_hit(damage, global_position, Enemy.DMG_PHYS, source_pid)
		if explode_radius > 0.0:
			_explode()
		if fire_puddle_radius > 0.0:
			_drop_fire_puddle()
		if on_hit.is_valid():
			on_hit.call(body, global_position, get_parent())
		queue_free()


func _explode() -> void:
	var fx := RingFx.new()
	fx.position = global_position
	fx.radius = radius
	fx.max_radius = explode_radius
	fx.life = 0.25
	fx.color = color
	get_parent().add_child(fx)
	Sfx.play("boom", global_position, -8.0)
	for e in EnemyGrid.near(global_position, explode_radius):
		if global_position.distance_to(e.global_position) <= explode_radius + e.radius:
			e.take_hit(explode_damage, global_position, Enemy.DMG_PHYS, source_pid)


func _drop_fire_puddle() -> void:
	var pud := VenomPuddle.new()
	pud.source_pid = fire_puddle_source_pid
	pud.radius = fire_puddle_radius
	pud.damage = fire_puddle_damage
	pud.max_life = fire_puddle_life
	pud.life = fire_puddle_life
	pud.fiery = true
	pud.burn_dps = fire_puddle_burn_dps
	pud.burn_dur = fire_puddle_burn_dur
	pud.position = global_position
	get_parent().add_child(pud)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
