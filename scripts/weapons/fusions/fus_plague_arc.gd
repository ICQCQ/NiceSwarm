# --- lightning + venom -------------------------------------------------------
class_name FusPlagueArc
extends WeaponBase

var cooldown := 0.9
func _init() -> void:
	weapon_id = "fus_plague"
	display_name = "Plague Arc"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	var first := player.nearest_enemy(cfg.range)
	if first == null:
		cooldown = 0.15
		return
	var dmg: float = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	var chains: int = cfg.chain_base + count_level()
	var pts: Array = [player.global_position]
	var visited := {}
	var cur: Node2D = first
	while cur != null and chains > 0:
		visited[cur.get_instance_id()] = true
		pts.append(cur.global_position)
		damage_dealt += dmg
		cur.take_hit(dmg, null, Enemy.DMG_ENERGY, player.peer_id)
		cur.apply_burn(dmg * cfg.poison_dps_ratio, cfg.poison_dur * fuse_duration(), 1.0, player.peer_id)  # virulent poison
		chains -= 1
		cur = _next(pts[pts.size() - 1], visited)
	var fx := LightningFx.new()
	fx.points = pts
	player.get_parent().add_child(fx)
	Sfx.play("lightning", player.global_position)
	cooldown = cfg.cd * fuse_rate()
func _next(from: Vector2, visited: Dictionary) -> Node2D:
	var best: Node2D = null
	var bd: float = cfg.chain_range * cfg.chain_range
	for e in Main.instance.enemies_in_radius(from, cfg.chain_range + 64.0):
		if visited.has(e.get_instance_id()):
			continue
		var d: float = from.distance_squared_to(e.global_position)
		if d < bd:
			bd = d
			best = e
	return best
