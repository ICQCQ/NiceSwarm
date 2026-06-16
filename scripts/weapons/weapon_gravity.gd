class_name WeaponGravity
extends WeaponBase
## Spawns gravity wells dragging the swarm together. Past Lv3 it opens more wells
## at once on separate targets: 1 well, +1 at Lv4, +1 at Lv6 (up to 3).

var cooldown := 2.0


func _init() -> void:
	weapon_id = "gravity"
	display_name = "Gravity Well"


func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	var target := player.nearest_enemy(700.0)
	if target == null:
		cooldown = 0.2
		return
	# Above-Lv3 kicker: more simultaneous wells on distinct nearby foes so high
	# levels carpet the field with vortices instead of dropping one well forever.
	var wells := 1
	if level >= 4:
		wells += 1
	if level >= 6:
		wells += 1
	for pos in _well_positions(target, wells):
		_spawn_well(pos)
	Sfx.play("gravity", target.global_position)
	cooldown = WeaponConfig.BASE.gravity.cd * player.rate_mult


func _spawn_well(pos: Vector2) -> void:
	var well := GravityWell.new()
	well.source_pid = player.peer_id
	well.source_weapon = self
	well.radius = (120.0 + 10.0 * (level - 1)) * player.area_mult  # nerfed field size (was 160 + 15/lv)
	well.damage = WeaponConfig.BASE.gravity.dmg * player.damage_mult * (1.0 + WeaponConfig.BASE.gravity.growth * (level - 1))
	well.pull = 170.0 + 15.0 * (level - 1)
	well.life = 2.5 * player.duration_mult
	well.position = pos
	player.get_parent().add_child(well)


## n drop points: the primary target plus the next-nearest distinct enemies,
## padding with a ring of offsets around the target when the swarm is too thin.
func _well_positions(primary: Node2D, n: int) -> Array:
	var out: Array = [primary.global_position]
	if n <= 1:
		return out
	# Any distinct nearby foes work as extra drop points; the grid query is already
	# locality-ordered, so take the first distinct ones without a full sort.
	for e in Main.instance.enemies_in_radius(player.global_position, 700.0):
		if out.size() >= n:
			break
		if e == primary:
			continue
		out.append(e.global_position)
	while out.size() < n:
		var ang := TAU * out.size() / float(n)
		out.append(primary.global_position + Vector2.from_angle(ang) * 120.0 * player.area_mult)
	return out
