# --- bolt + lightning --------------------------------------------------------
class_name FusRailgun
extends WeaponBase

var cooldown := 0.7
func _init() -> void:
	weapon_id = "fus_railgun"
	display_name = "Railgun"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	var target := player.nearest_enemy(cfg.length)
	if target == null:
		cooldown = 0.1
		return
	var dir := (target.global_position - player.global_position).normalized()
	var length: float = cfg.length * fuse_area()            # long line-of-sight rail
	var zap_r: float = randf_range(cfg.zap_r_min, cfg.zap_r_max) * fuse_area()   # erratic corridor reach (not a fixed beam)
	var dmg: float = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	var origin := player.global_position
	var fx := LightningFx.new()
	fx.points = [origin, origin + dir * length]
	player.get_parent().add_child(fx)
	var visited := {}
	for e in Main.instance.enemies_in_radius(origin, length + zap_r + 64.0):
		var rel: Vector2 = e.global_position - origin
		var along := rel.dot(dir)
		if along < 0.0 or along > length:
			continue
		var beam_pt := origin + dir * along
		if beam_pt.distance_to(e.global_position) > zap_r + e.radius:
			continue
		if visited.has(e.get_instance_id()):
			continue
		visited[e.get_instance_id()] = true
		damage_dealt += dmg
		e.take_hit(dmg, origin, Enemy.DMG_PHYS, player.peer_id)
		ignite(e, dmg)
		var z := LightningFx.new()            # arc from the beam to each zapped foe
		z.points = [beam_pt, e.global_position]
		player.get_parent().add_child(z)
		_bounce(e, dmg * cfg.bounce_dmg_ratio, randi_range(cfg.hops_min, cfg.hops_max), visited)   # erratic 1-2 hops to RANDOM foes
	Sfx.play("lightning", origin)
	cooldown = cfg.cd * fuse_rate()


## Erratic chain: bounce from `src` to a RANDOM nearby unvisited enemy (not the nearest —
## so it never forms the same fixed tree that Chain Lightning does), up to `hops` times.
func _bounce(src: Node2D, dmg: float, hops: int, visited: Dictionary) -> void:
	if hops <= 0 or player == null:
		return
	var reach: float = randf_range(cfg.bounce_reach_min, cfg.bounce_reach_max) * fuse_area()   # bounce reach is kind of random too
	var candidates: Array = []
	for e in Main.instance.enemies_in_radius(src.global_position, reach + 64.0):
		if visited.has(e.get_instance_id()):
			continue
		if src.global_position.distance_to(e.global_position) <= reach + e.radius:
			candidates.append(e)
	if candidates.is_empty():
		return
	var nxt: Node2D = candidates[randi() % candidates.size()]   # RANDOM target, not nearest
	visited[nxt.get_instance_id()] = true
	damage_dealt += dmg
	nxt.take_hit(dmg, src.global_position, Enemy.DMG_PHYS, player.peer_id)
	ignite(nxt, dmg)
	var bz := LightningFx.new()
	bz.points = [src.global_position, nxt.global_position]
	player.get_parent().add_child(bz)
	_bounce(nxt, dmg * cfg.bounce_decay, hops - 1, visited)
