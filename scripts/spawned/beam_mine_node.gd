class_name BeamMineNode
extends Node2D
## Beam Mine: doesn't explode on contact. While alive, it links a sustained
## damaging laser to every other Beam Mine within range (Area widens the
## link range), forming a network. Enemy contact arms a delayed fuse instead
## of detonating instantly -- it goes inert for `inert_dur` (scales with
## Duration; the baseline runs longer than a normal mine's whole life) while
## the beams keep firing, then finally explodes like a normal mine and is
## destroyed. Never-triggered mines just fizzle out at `life`.

const HIT_COOLDOWN := 0.3  # per (enemy, link) re-hit interval, mirrors SpinLaser

var blast_dmg := 2.0
var blast_radius := 100.0
var link_dmg := 2.0
var source_pid := -1
var source_weapon: WeaponBase
var owner_weapon_id := -1
var trigger_radius := 50.0
var link_range := 220.0
var beam_width := 6.0
var life := 20.0  # only matters if never triggered
var inert_dur := 14.0  # Duration: fuse length after contact, before it detonates
var rate_mult := 1.0  # Haste: per-(enemy,link) re-hit cooldown
var arm := 0.4
var triggered := false
var fuse_timer := 0.0
var t := 0.0
var hit_cd := {}
var _links: Array = []  # neighbor beam mines this instance owns drawing/damage for (id > self)

var _trigger: Area2D


func _ready() -> void:
	add_to_group("beam_mines")
	z_index = -1
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
	if arm > 0.0 or triggered or not (body is Enemy):
		return
	triggered = true
	fuse_timer = inert_dur
	var fx := RingFx.new()
	fx.position = global_position
	fx.radius = 6.0
	fx.max_radius = trigger_radius
	fx.life = 0.25
	fx.color = Color(0.4, 0.8, 1.0)
	get_parent().add_child(fx)
	Sfx.play("laser", global_position, -6.0)


func _physics_process(delta: float) -> void:
	t += delta
	arm -= delta
	if triggered:
		fuse_timer -= delta
		if fuse_timer <= 0.0:
			_explode()
			return
	else:
		life -= delta
		if life <= 0.0:
			queue_free()  # never triggered: fizzles out, no blast
			return
	# Canonical ordering: only the lower-id mine in a pair draws/damages the
	# link, so each beam between two mines is counted exactly once. Beams
	# stay live whether the mine is armed or inert-and-fusing.
	_links.clear()
	for node in get_tree().get_nodes_in_group("beam_mines"):
		if node == self or node.get_instance_id() < get_instance_id():
			continue
		if global_position.distance_to(node.global_position) <= link_range:
			_links.append(node)
	var expired := []
	for k in hit_cd:
		hit_cd[k] -= delta
		if hit_cd[k] <= 0.0:
			expired.append(k)
	for k in expired:
		hit_cd.erase(k)
	for other in _links:
		_zap_along(other)
	queue_redraw()


func _zap_along(other: Node2D) -> void:
	var to_other: Vector2 = other.global_position - global_position
	var dist := to_other.length()
	if dist < 1.0:
		return
	var dir := to_other / dist
	for e in EnemyGrid.near(global_position, dist):
		var rel: Vector2 = e.global_position - global_position
		var along := clampf(rel.dot(dir), 0.0, dist)
		if (dir * along).distance_to(rel) > beam_width + e.radius:
			continue
		var key := "%d_%d" % [e.get_instance_id(), other.get_instance_id()]
		if hit_cd.has(key):
			continue
		if is_instance_valid(source_weapon):
			source_weapon.damage_dealt += link_dmg
		e.take_hit(link_dmg, global_position + dir * along, Enemy.DMG_ENERGY, source_pid)
		hit_cd[key] = HIT_COOLDOWN * rate_mult


func _explode() -> void:
	var fx := RingFx.new()
	fx.position = global_position
	fx.radius = 20.0
	fx.max_radius = blast_radius
	fx.life = 0.3
	fx.color = Color(0.3, 0.8, 1.0)
	get_parent().add_child(fx)
	Sfx.play("boom", global_position, -4.0)
	for e in EnemyGrid.near(global_position, blast_radius):
		if global_position.distance_to(e.global_position) <= blast_radius + e.radius:
			if is_instance_valid(source_weapon):
				source_weapon.damage_dealt += blast_dmg
			e.take_hit(blast_dmg, global_position, Enemy.DMG_ENERGY, source_pid)
	queue_free()


func _draw() -> void:
	var blink: bool
	var core: Color
	if triggered:
		# blink faster as the fuse runs down toward detonation
		var period: float = clampf(fuse_timer / maxf(inert_dur, 0.01), 0.1, 1.0) * 0.6
		blink = fmod(t, period) < period * 0.5
		core = Color(1.0, 0.35, 0.2) if blink else Color(0.5, 0.15, 0.1)
	else:
		blink = fmod(t, 0.8) < 0.4
		core = Color(0.3, 0.85, 1.0) if blink else Color(0.15, 0.45, 0.55)
	draw_circle(Vector2.ZERO, 7.0, Color(0.35, 0.35, 0.4))
	draw_circle(Vector2.ZERO, 2.5, core)
	for other in _links:
		var rel: Vector2 = other.global_position - global_position
		draw_line(Vector2.ZERO, rel, Color(0.3, 0.8, 1.0, 0.22), 9.0)
		draw_line(Vector2.ZERO, rel, Color(0.6, 0.95, 1.0, 0.55), 3.0)
