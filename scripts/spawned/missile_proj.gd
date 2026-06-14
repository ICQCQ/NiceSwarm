class_name MissileProj
extends Node2D
## Homing missile: steers toward its target, explodes with splash damage.

var damage := 3.0
var source_pid := -1  # scoreboard: which player owns this
var splash := 70.0
var velocity := Vector2.ZERO
var life := 4.0
var target: Node2D
var freeze_slow := 0.0  # >0: slow enemies in splash (Cryo Missile); duration scales with damage
var freeze_dur := 0.0
var fire_dps := 0.0      # fused Phoenix Rocket: leaves a burning pool on impact
var fire_radius := 0.0
var fire_dur := 0.0
var venom_dps := 0.0     # fused Plague Rocket: leaves a toxic pool on impact
var venom_radius := 0.0
var venom_dur := 0.0
var shrapnel_count := 0  # fused Rotor Missile: glaive shards fly outward on impact
var shrapnel_dmg := 0.0
var shrapnel_radius := 12.0
var chain_count := 0     # fused EMP Missile: lightning chains out from the impact
var chain_dmg := 0.0
var chain_range := 0.0


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	if target == null or not is_instance_valid(target):
		target = _find_target()
	if target != null:
		var desired := (target.global_position - global_position).normalized() * 380.0
		velocity = velocity.lerp(desired, 4.0 * delta)
	position += velocity * delta
	rotation = velocity.angle()
	queue_redraw()
	if target != null and is_instance_valid(target) \
			and global_position.distance_to(target.global_position) <= 10.0 + target.radius:
		_explode()


func _find_target() -> Node2D:
	var best: Node2D = null
	var best_d := 800.0 * 800.0
	for e in EnemyGrid.near(global_position, 800.0):
		var d: float = global_position.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _explode() -> void:
	var fx := RingFx.new()
	fx.position = global_position
	fx.radius = 12.0
	fx.max_radius = splash
	fx.life = 0.25
	fx.color = Color(1.0, 0.6, 0.3)
	get_parent().add_child(fx)
	Sfx.play("boom", global_position, -10.0)
	for e in EnemyGrid.near(global_position, splash):
		if global_position.distance_to(e.global_position) <= splash + e.radius:
			e.take_hit(damage, global_position, Enemy.DMG_PHYS, source_pid)
			if freeze_slow > 0.0:
				e.apply_slow(freeze_slow, freeze_dur)
	if fire_dps > 0.0:
		var pud := VenomPuddle.new()
		pud.source_pid = source_pid
		pud.radius = fire_radius
		pud.damage = fire_dps
		pud.max_life = fire_dur
		pud.life = fire_dur
		pud.fiery = true
		pud.burn_dps = fire_dps
		pud.burn_dur = 1.0
		pud.position = global_position
		get_parent().add_child(pud)
	if venom_dps > 0.0:
		var tpud := VenomPuddle.new()
		tpud.source_pid = source_pid
		tpud.radius = venom_radius
		tpud.damage = venom_dps
		tpud.max_life = venom_dur
		tpud.life = venom_dur
		tpud.burn_dps = venom_dps * 0.5
		tpud.burn_dur = venom_dur * 0.5
		tpud.position = global_position
		get_parent().add_child(tpud)
	for i in shrapnel_count:
		var g := GlaiveProj.new()
		g.source_pid = source_pid
		g.velocity = Vector2.from_angle(TAU * float(i) / shrapnel_count) * 420.0
		g.damage = shrapnel_dmg
		g.hit_radius = shrapnel_radius
		g.position = global_position
		get_parent().add_child(g)
	if chain_count > 0:
		var visited := {}
		for e in EnemyGrid.near(global_position, splash):
			if global_position.distance_to(e.global_position) <= splash + e.radius:
				visited[e.get_instance_id()] = true
		var from_pos := global_position
		for i in chain_count:
			var best: Node2D = null
			var bd := chain_range * chain_range
			for e in EnemyGrid.near(from_pos, chain_range):
				if visited.has(e.get_instance_id()):
					continue
				var d: float = from_pos.distance_squared_to(e.global_position)
				if d < bd:
					bd = d
					best = e
			if best == null:
				break
			visited[best.get_instance_id()] = true
			best.take_hit(chain_dmg, from_pos, Enemy.DMG_ENERGY, source_pid)
			var cfx := LightningFx.new()
			cfx.points = [from_pos, best.global_position]
			get_parent().add_child(cfx)
			from_pos = best.global_position
	queue_free()


func _draw() -> void:
	draw_polygon(
		PackedVector2Array([Vector2(9, 0), Vector2(-6, -5), Vector2(-6, 5)]),
		PackedColorArray([Color(0.85, 0.85, 0.9)])
	)
	draw_circle(Vector2(-7, 0), 2.5, Color(1.0, 0.6, 0.2, randf_range(0.5, 1.0)))
