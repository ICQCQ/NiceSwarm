# --- lightning + nova: a blast that forks lightning --------------------------
class_name FusThunderclap
extends WeaponBase

var cooldown := 1.4
func _init() -> void:
	weapon_id = "fus_thunderclap"
	display_name = "Thunderclap"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	# Ring = nova's body, so size it from the MAXED nova ring (Lv7 = 310) and retain it at
	# birth: count_level() is born-floored, so a fresh fusion opens at ~310 (>=300), not 140.
	# Per-hit damage still climbs with the real `level` (the leveling reward).
	var radius := (170.0 + 28.0 * (count_level() - 1)) * fuse_area()  # born 310 (cl6), max 338 (cl7)
	var dmg := 12.0 * fuse_damage() * (1.0 + 0.4 * (level - 1))  # Lv1 ~= 0.9x maxed nova (13.35)
	var hits: Array = []
	for e in Main.instance.enemies_in_radius(global_position, radius + 64.0):
		if global_position.distance_to(e.global_position) <= radius + e.radius:
			damage_dealt += dmg
			e.take_hit(dmg, global_position, Enemy.DMG_ENERGY, player.peer_id)
			push(e, global_position)
			hits.append(e)
	if hits.is_empty():
		cooldown = 0.25
		return
	var fx := RingFx.new()
	fx.position = global_position
	fx.radius = 25.0
	fx.max_radius = radius
	fx.life = 0.35
	fx.color = Color(0.8, 0.85, 1.0)
	player.get_parent().add_child(fx)
	hits.shuffle()
	# Forks = lightning's body: born firing near-max chains (count_level floored) ~= maxed
	# lightning's 9 chains, each at dmg*0.6 (~7.2) ~= maxed lightning per-hit (7.52).
	for h in hits.slice(0, 3 + count_level()):
		var nb := _nearest_beyond(h.global_position, radius * 1.6)
		if nb != null:
			damage_dealt += dmg * 0.6
			nb.take_hit(dmg * 0.6, null, Enemy.DMG_ENERGY, player.peer_id)
			var lf := LightningFx.new()
			lf.points = [h.global_position, nb.global_position]
			player.get_parent().add_child(lf)
	Sfx.play("lightning", global_position)
	cooldown = 2.2 * fuse_rate()
func _nearest_beyond(from: Vector2, rng: float) -> Node2D:
	var best: Node2D = null
	var bd := rng * rng
	for e in Main.instance.enemies_in_radius(from, rng + 64.0):
		if from.distance_to(e.global_position) < 12.0:
			continue
		var d: float = from.distance_squared_to(e.global_position)
		if d < bd:
			bd = d
			best = e
	return best
