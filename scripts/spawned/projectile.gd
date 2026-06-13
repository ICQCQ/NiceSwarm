class_name Projectile
extends Area2D
## Straight-flying bolt; dies on first enemy hit or after its lifetime.

var velocity := Vector2.ZERO
var damage := 1.0
var life := 1.6
var radius := 5.0  # scaled by the firing weapon's Area stat
var explode_radius := 0.0  # >0: burst into an AoE on hit (fused Plasma Burst)
var explode_damage := 0.0
var color := Color(1.0, 0.92, 0.4)


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
	position += velocity * delta
	life -= delta
	if life <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body is Enemy:
		body.take_hit(damage, global_position)
		if explode_radius > 0.0:
			_explode()
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
	for e in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(e.global_position) <= explode_radius + e.radius:
			e.take_hit(explode_damage, global_position)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
