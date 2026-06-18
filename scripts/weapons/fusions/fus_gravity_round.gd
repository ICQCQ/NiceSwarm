# --- bolt + gravity: bolt spawns a gravity well at impact --------------------
class_name FusGravityRound
extends WeaponBase

var cooldown := 0.9
func _init() -> void:
	weapon_id = "fus_gravround"
	display_name = "Gravity Round"
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
	var dir := (target.global_position - player.global_position).normalized()
	var dmg: float = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	var count := count_level()  # near-max salvo at birth (count_level floors for fresh fusions), capped at MAX
	for i in count:
		var spread := deg_to_rad(cfg.spread_deg) * (i - (count - 1) / 2.0)
		var p := Projectile.new()
		p.source_pid = player.peer_id
		p.source_weapon = self
		p.velocity = dir.rotated(spread) * cfg.speed
		p.damage = dmg
		p.radius = cfg.radius * fuse_area()
		p.life = cfg.life * fuse_duration()
		p.color = Color(0.7, 0.5, 1.0)
		p.on_hit = Callable(self, "_spawn_well")
		p.position = player.global_position
		player.get_parent().add_child(p)
	Sfx.play("bolt", player.global_position)
	cooldown = cfg.cd * fuse_rate()
func _spawn_well(_enemy: Node2D, hit_pos: Vector2, world: Node) -> void:
	if player == null:
		return
	var w := GravityWell.new()
	w.source_pid = player.peer_id
	w.source_weapon = self
	w.radius = (cfg.well_radius + cfg.well_radius_per_level * (level - 1)) * fuse_area()
	w.damage = cfg.well_dmg * fuse_damage() * (1.0 + cfg.well_growth * (level - 1))
	w.pull = cfg.well_pull
	w.life = cfg.well_life * fuse_duration()
	w.position = hit_pos
	world.add_child(w)
	Sfx.play("gravity", hit_pos, -6.0)
