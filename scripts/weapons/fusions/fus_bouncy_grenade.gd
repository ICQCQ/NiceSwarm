# --- mines + orbit: launches a batch of grenades that bounce between enemies,
# exploding on every landing -- the final hop in each chain hits hardest -----
class_name FusBouncyGrenade
extends WeaponBase

var batch_cd := 0.0
func _init() -> void:
	weapon_id = "fus_bouncygrenade"
	display_name = "Bouncy Grenade"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	batch_cd -= delta
	if batch_cd > 0.0:
		return
	var range_min: float = cfg.range_min * fuse_duration()  # Duration: hop target band
	var range_max: float = cfg.range_max * fuse_duration()
	var grenade_count: int = cfg.count_base + count_level()
	var hops: int = cfg.hop_count_base + count_level()       # Level: hops per grenade
	var dmg: float = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	var blast_radius: float = cfg.blast_radius * fuse_area()  # Area: explosion size
	var launched := 0
	for i in grenade_count:
		var target := _pick_target(player.global_position, range_min, range_max)
		if target == null:
			continue
		var g := GrenadeProj.new()
		g.source_pid = player.peer_id
		g.source_weapon = self
		g.start_pos = player.global_position
		g.land_pos = target.global_position
		g.travel_time = clampf(g.start_pos.distance_to(g.land_pos) / 280.0, 0.45, 1.4)
		g.dmg = dmg
		g.final_dmg_mult = cfg.final_dmg_mult
		g.blast_radius = blast_radius
		g.final_radius_mult = cfg.final_radius_mult
		g.hops_left = hops - 1
		g.range_min = range_min
		g.range_max = range_max
		g.position = g.start_pos
		player.get_parent().add_child(g)
		launched += 1
	if launched > 0:
		Sfx.play("mine", player.global_position)
		batch_cd = cfg.batch_cd * fuse_rate()  # Haste: cooldown between batches
	else:
		batch_cd = 0.2  # no targets yet -- retry soon instead of burning the full cooldown
func _pick_target(from: Vector2, range_min: float, range_max: float) -> Node2D:
	var near := Main.instance.enemies_in_radius(from, range_max)
	var candidates: Array = []
	for e in near:
		var d := from.distance_to(e.global_position)
		if d <= range_max and d >= range_min:
			candidates.append(e)
	if candidates.is_empty():
		for e in near:
			if from.distance_to(e.global_position) <= range_max:
				candidates.append(e)
	if candidates.is_empty():
		return null
	return candidates[randi() % candidates.size()]
