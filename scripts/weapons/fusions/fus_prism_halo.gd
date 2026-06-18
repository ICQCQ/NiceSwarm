# --- laser + orbit: prisms periodically drop at a fixed distance around you, -
# each linking back to you and to one other prism — the links zap anything ---
# they cross, for as long as that prism survives ------------------------------
class_name FusPrismHalo
extends WeaponBase

const MIN_TICK := 0.12  # floor so high Haste can't make zaps near-continuous
var prisms: Array[Dictionary] = []  # {pos: Vector2 (global, fixed at drop), life, max_life}
var hit_cd := {}
var spawn_timer := 0.0
func _init() -> void:
	weapon_id = "fus_prism"
	display_name = "Prism Halo"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		queue_redraw()
		return
	for p in prisms:
		p.life -= delta
	prisms = prisms.filter(func(p): return p.life > 0.0)
	var max_n: int = cfg.count_base + count_level()  # Level: max concurrent prisms
	spawn_timer -= delta
	if prisms.size() < max_n and spawn_timer <= 0.0:
		spawn_timer = cfg.spawn_cd * fuse_rate()  # Haste: time between new prisms
		var life: float = cfg.lifetime * fuse_duration()  # Duration: max prism lifetime
		var dist: float = cfg.place_dist * fuse_area()  # Area: drop distance from you
		var drop_pos: Vector2 = player.global_position + Vector2.from_angle(randf() * TAU) * dist
		prisms.append({
			"pos": drop_pos,
			"life": life,
			"max_life": life,
		})
		Sfx.play("prism", drop_pos)
	var exp := []
	for k in hit_cd:
		hit_cd[k] -= delta
		if hit_cd[k] <= 0.0:
			exp.append(k)
	for k in exp:
		hit_cd.erase(k)
	var dmg: float = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	var hit_radius: float = cfg.hit_radius * fuse_area()
	var n: int = prisms.size()
	for i in n:
		_zap_link(prisms[i].pos, player.global_position, dmg, hit_radius)
	for i in _ring_edges(n):
		_zap_link(prisms[i].pos, prisms[(i + 1) % n].pos, dmg, hit_radius)
	queue_redraw()
## Each prism always links to you AND to one other prism, forming a ring
## between the prisms themselves. A ring needs >=3 points for every edge to
## be distinct; at exactly 2, the "next" edge from each end is the same pair,
## so only count it once (n<2 has no other prism to link to at all).
func _ring_edges(n: int) -> int:
	if n > 2:
		return n
	return 1 if n == 2 else 0
func _zap_link(a: Vector2, b: Vector2, dmg: float, hit_radius: float) -> void:
	var seg: Vector2 = b - a
	var dist: float = seg.length()
	if dist <= 0.0:
		return
	var dir: Vector2 = seg / dist
	for e in Main.instance.enemies_in_radius(a, dist + 64.0):
		if hit_cd.has(e.get_instance_id()):
			continue
		var rel: Vector2 = e.global_position - a
		var along: float = clampf(rel.dot(dir), 0.0, dist)
		if (dir * along).distance_to(rel) <= hit_radius + e.radius:
			damage_dealt += dmg
			e.take_hit(dmg, a + dir * along, Enemy.DMG_ENERGY, player.peer_id)
			ignite(e, dmg)
			hit_cd[e.get_instance_id()] = maxf(cfg.tick_cd * fuse_rate(), MIN_TICK)  # Haste: tick rate
			Sfx.play("laser", e.global_position)
func _draw() -> void:
	if player == null or player.downed:
		return
	var n: int = prisms.size()
	var ring_edges: int = _ring_edges(n)
	for i in n:
		var local: Vector2 = prisms[i].pos - global_position
		var a: float = clampf(prisms[i].life / prisms[i].max_life, 0.0, 1.0)
		draw_line(Vector2.ZERO, local, Color(0.75, 0.55, 1.0, 0.3 * a), 2.5)
		if i < ring_edges:
			var nxt: Vector2 = prisms[(i + 1) % n].pos - global_position
			draw_line(local, nxt, Color(0.85, 0.65, 1.0, 0.4 * a), 3.5)
		draw_circle(local, 9.0 * fuse_area(), Color(0.85, 0.6, 1.0, a))
		draw_circle(local, 4.5 * fuse_area(), Color(1.0, 0.92, 1.0, a))
