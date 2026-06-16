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
	var first := player.nearest_enemy(520.0)
	if first == null:
		cooldown = 0.15
		return
	var dmg := 2.2 * fuse_damage() * (1.0 + 0.35 * (level - 1))
	var chains := 3 + count_level()
	var pts: Array = [player.global_position]
	var visited := {}
	var cur: Node2D = first
	while cur != null and chains > 0:
		visited[cur.get_instance_id()] = true
		pts.append(cur.global_position)
		damage_dealt += dmg
		cur.take_hit(dmg, null, Enemy.DMG_ENERGY, player.peer_id)
		cur.apply_burn(dmg * 0.4, 2.0 * fuse_duration(), 1.0, player.peer_id)  # virulent poison
		chains -= 1
		cur = _next(pts[pts.size() - 1], visited)
	var fx := LightningFx.new()
	fx.points = pts
	player.get_parent().add_child(fx)
	Sfx.play("lightning", player.global_position)
	cooldown = 1.9 * fuse_rate()
func _next(from: Vector2, visited: Dictionary) -> Node2D:
	var best: Node2D = null
	var bd := 210.0 * 210.0
	for e in Main.instance.enemies_in_radius(from, 210.0 + 64.0):
		if visited.has(e.get_instance_id()):
			continue
		var d: float = from.distance_squared_to(e.global_position)
		if d < bd:
			bd = d
			best = e
	return best
