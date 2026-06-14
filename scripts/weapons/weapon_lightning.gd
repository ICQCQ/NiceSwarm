class_name WeaponLightning
extends WeaponBase
## Chain lightning: zaps the nearest enemy and arcs to others nearby.

var cooldown := 0.8


func _init() -> void:
	weapon_id = "lightning"
	display_name = "Chain Lightning"


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
	var dmg := WeaponConfig.BASE.lightning.dmg * player.damage_mult * (1.0 + WeaponConfig.BASE.lightning.growth * (level - 1))
	var chains := 2 + level
	var points: Array = [player.global_position]
	var visited := {}
	var current: Node2D = first
	var dmgDrop = 0
	while current != null and chains > 0:
		visited[current.get_instance_id()] = true
		points.append(current.global_position)
		current.take_hit(dmg - dmgDrop, null, Enemy.DMG_ENERGY, player.peer_id)
		ignite(current, dmg - dmgDrop)
		chains -= 1
		dmgDrop += 1
		current = _next_target(points[points.size() - 1], visited)
	var fx := LightningFx.new()
	fx.points = points
	player.get_parent().add_child(fx)
	Sfx.play("lightning", player.global_position)
	cooldown = WeaponConfig.BASE.lightning.cd * player.rate_mult


func _next_target(from: Vector2, visited: Dictionary) -> Node2D:
	var best: Node2D = null
	var jump := 200.0 * player.area_mult
	var best_d := jump * jump
	for e in Main.instance.all_enemies():
		if visited.has(e.get_instance_id()):
			continue
		var d: float = from.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best
