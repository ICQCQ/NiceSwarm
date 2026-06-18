class_name GroundCurrentField
extends Node2D
## Ground Current zone: every enemy currently standing in it becomes its own
## lightning source, chaining outward to nearby enemies — re-zapping on its own
## tick interval for as long as the field stays alive.
##
## Cost per zap is sources x hops x a local EnemyGrid query each hop. With many
## sources (a field landing in a packed swarm) and many hops (level + unbounded
## Duration-pick count) that product can spike hard, so both are capped below —
## a worst case stays a small constant instead of scaling with mob count.

const MAX_SOURCES_PER_ZAP := 6   # extra enemies in a packed field don't add more chains
const MAX_CHAIN_HOPS := 8        # hard ceiling regardless of level + Duration picks
const MIN_TICK_INTERVAL := 0.25  # floor so high Haste can't make zaps near-continuous

var radius := 120.0
var life := 3.0
var max_life := 3.0
var tick_interval := 0.5   # Haste
var dmg := 3.0
var chain_count := 3       # hops per source enemy — scales with level + Duration picks
var chain_range := 180.0   # Area
var poison_ratio := 0.35
var poison_dur := 1.5      # Duration
var source_pid := -1
var source_weapon: WeaponBase
var tick := 0.0
var redraw_tick := 0.0


func _ready() -> void:
	add_to_group("ground_current_fields")
	z_index = -1
	queue_redraw()


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	redraw_tick -= delta
	if redraw_tick <= 0.0:
		redraw_tick = 0.08  # redraw fast — a live wire should crackle, not fade smoothly
		queue_redraw()
	tick -= delta
	if tick <= 0.0:
		tick = maxf(tick_interval, MIN_TICK_INTERVAL)
		_zap()


func _zap() -> void:
	var in_field: Array = []
	for e in EnemyGrid.near(global_position, radius):
		if global_position.distance_to(e.global_position) <= radius + e.radius:
			in_field.append(e)
	if in_field.size() > MAX_SOURCES_PER_ZAP:
		in_field.shuffle()
		in_field.resize(MAX_SOURCES_PER_ZAP)
	var any := false
	var hops: int = mini(chain_count, MAX_CHAIN_HOPS)
	for src in in_field:
		var visited := {src.get_instance_id(): true}
		var pts: Array = [src.global_position]
		_strike(src)
		any = true
		var cur: Node2D = src
		var left := hops
		while left > 0:
			var nxt := _nearest(cur.global_position, visited)
			if nxt == null:
				break
			visited[nxt.get_instance_id()] = true
			pts.append(nxt.global_position)
			_strike(nxt)
			cur = nxt
			left -= 1
		if pts.size() > 1:
			var fx := LightningFx.new()
			fx.points = pts
			get_parent().add_child(fx)
	if any:
		Sfx.play("lightning", global_position, -6.0)


func _strike(e: Node2D) -> void:
	if is_instance_valid(source_weapon):
		source_weapon.damage_dealt += dmg
	e.take_hit(dmg, null, Enemy.DMG_ENERGY, source_pid)
	e.apply_burn(dmg * poison_ratio, poison_dur, 1.0, source_pid)


func _nearest(from: Vector2, visited: Dictionary) -> Node2D:
	var best: Node2D = null
	var bd: float = chain_range * chain_range
	for e in EnemyGrid.near(from, chain_range):
		if visited.has(e.get_instance_id()):
			continue
		var d: float = from.distance_squared_to(e.global_position)
		if d < bd:
			bd = d
			best = e
	return best


func _draw() -> void:
	var a := clampf(life / max_life, 0.0, 1.0)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, Color(0.55, 0.85, 1.0, 0.22 * a), 2.0)
	for i in 5:
		var ang := randf() * TAU
		var r := randf_range(radius * 0.15, radius)
		draw_line(Vector2.ZERO, Vector2.from_angle(ang) * r, Color(0.75, 0.92, 1.0, 0.55 * a), 1.5)
