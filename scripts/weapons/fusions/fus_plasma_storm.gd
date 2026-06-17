# --- flame + lightning -------------------------------------------------------
class_name FusPlasmaStorm
extends WeaponBase

const TICK := 0.14
const HALF := 0.62
var tick := 0.0
var bolt_cd := 0.0
func _init() -> void:
	weapon_id = "fus_plasmastorm"
	display_name = "Plasma Storm"
func _physics_process(delta: float) -> void:
	queue_redraw()
	if player == null or player.downed:
		return
	var reach := (160.0 + 12.0 * (level - 1)) * fuse_area()
	tick -= delta
	if tick <= 0.0:
		tick = TICK * fuse_rate()
		var dmg := 1.5 * fuse_damage() * (1.0 + GameConfig.FUSION_LEVEL_GROWTH * (level - 1))
		for e in Main.instance.enemies_in_radius(player.global_position, reach + 64.0):
			var to: Vector2 = e.global_position - player.global_position
			if to.length() <= reach + e.radius and absf(player.facing.angle_to(to)) <= HALF:
				damage_dealt += dmg
				e.take_hit(dmg, null, Enemy.DMG_FIRE, player.peer_id)
				ignite(e, dmg)
		Sfx.play("flame", player.global_position)
	bolt_cd -= delta
	if bolt_cd <= 0.0:
		var first := player.nearest_enemy(reach + 60.0)
		if first != null:
			var bdmg := 5.0 * fuse_damage() * (1.0 + GameConfig.FUSION_LEVEL_GROWTH * (level - 1))
			var chains := 2 + count_level()
			var pts: Array = [player.global_position]
			var visited := {}
			var cur: Node2D = first
			while cur != null and chains > 0:
				visited[cur.get_instance_id()] = true
				pts.append(cur.global_position)
				damage_dealt += bdmg
				cur.take_hit(bdmg, null, Enemy.DMG_ENERGY, player.peer_id)
				chains -= 1
				cur = _next(pts[pts.size() - 1], visited)
			var fx := LightningFx.new()
			fx.points = pts
			player.get_parent().add_child(fx)
			Sfx.play("lightning", player.global_position)
			bolt_cd = 1.4 * fuse_rate()
		else:
			bolt_cd = 0.2
func _next(from: Vector2, visited: Dictionary) -> Node2D:
	var best: Node2D = null
	var bd := 200.0 * 200.0
	for e in Main.instance.enemies_in_radius(from, 200.0 + 64.0):
		if visited.has(e.get_instance_id()):
			continue
		var d: float = from.distance_squared_to(e.global_position)
		if d < bd:
			bd = d
			best = e
	return best
func _draw() -> void:
	if player == null or player.downed:
		return
	var reach := (160.0 + 12.0 * (level - 1)) * fuse_area()
	var base_a := player.facing.angle()
	for i in 7:
		var ang := base_a + randf_range(-HALF * 0.8, HALF * 0.8)
		var dist := randf_range(reach * 0.25, reach)
		draw_circle(Vector2.from_angle(ang) * dist, randf_range(4.0, 10.0),
			Color(0.7, 0.6, 1.0, randf_range(0.3, 0.6)))
