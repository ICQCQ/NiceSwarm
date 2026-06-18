# --- bolt + glaive: bolt chains to next enemy on hit -------------------------
class_name FusRicochet
extends WeaponBase

var cooldown := 0.6
func _init() -> void:
	weapon_id = "fus_ricochet"
	display_name = "Ricochet"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	var target := player.nearest_enemy(cfg.range)
	if target == null:
		cooldown = 0.1
		return
	var visited := {target.get_instance_id(): true}
	_fire(player.global_position, target, count_level(), visited, 1.0)
	Sfx.play("bolt", player.global_position)
	cooldown = cfg.cd * fuse_rate()
func _fire(from: Vector2, toward: Node2D, hops_left: int, visited: Dictionary, dmg_scale: float) -> void:
	var dir := (toward.global_position - from).normalized()
	var p := Projectile.new()
	p.source_pid = player.peer_id
	p.source_weapon = self
	p.velocity = dir * cfg.speed
	p.damage = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1)) * dmg_scale
	p.radius = cfg.radius * fuse_area()
	p.life = cfg.life * fuse_duration()
	p.color = Color(0.95, 0.8, 0.2)
	if hops_left > 0:
		p.on_hit = Callable(self, "_chain").bind(hops_left, visited.duplicate(), dmg_scale * cfg.chain_decay)
	p.position = from
	# _fire is also called from _chain (an on_hit callback) — i.e. during physics
	# query flush, where a synchronous Area2D add throws "can't change monitoring
	# state". Defer it; harmless when _fire runs from _physics_process too.
	player.get_parent().add_child.call_deferred(p)
func _chain(enemy: Node2D, hit_pos: Vector2, _world: Node, hops_left: int, visited: Dictionary, dmg_scale: float) -> void:
	if player == null:
		return
	var chain_r: float = cfg.chain_range * fuse_area()
	var best: Node2D = null
	var bd := chain_r * chain_r
	for e in Main.instance.enemies_in_radius(hit_pos, chain_r + 64.0):
		if visited.has(e.get_instance_id()):
			continue
		var d := hit_pos.distance_squared_to(e.global_position)
		if d < bd:
			bd = d
			best = e
	if best == null:
		return
	visited[best.get_instance_id()] = true
	_fire(hit_pos, best, hops_left - 1, visited, dmg_scale)
	Sfx.play("bolt", hit_pos, -10.0)
