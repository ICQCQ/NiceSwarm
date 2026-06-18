# --- glaive + gravity: glaives + a vortex on the target ----------------------
class_name FusVortexBlade
extends WeaponBase

var cooldown := 1.0
func _init() -> void:
	weapon_id = "fus_vortexblade"
	display_name = "Vortex Blade"
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
	var base := (target.global_position - player.global_position).normalized()
	var count: int = cfg.count_base + count_level()
	for i in count:
		var g := GlaiveProj.new()
		g.source_pid = player.peer_id
		g.source_weapon = self
		g.player = player
		g.velocity = base.rotated(deg_to_rad(cfg.spread_deg) * (i - (count - 1) / 2.0)) * cfg.speed
		g.damage = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
		g.hit_radius = cfg.hit_radius * fuse_area()
		g.on_hit = Callable(self, "_on_glaive_hit")
		g.position = player.global_position
		player.get_parent().add_child(g)
	Sfx.play("glaive", player.global_position)
	cooldown = cfg.cd * fuse_rate()

## Each glaive hit drops a small gravity well at the hit point, on top of
## the glaive's own direct damage.
func _on_glaive_hit(_e: Node2D, pos: Vector2) -> void:
	var w := GravityWell.new()
	w.source_pid = player.peer_id
	w.source_weapon = self
	w.radius = (cfg.well_radius + cfg.well_radius_per_level * (level - 1)) * fuse_area()
	w.damage = cfg.well_dmg * fuse_damage() * (1.0 + cfg.well_growth * (level - 1))
	w.pull = cfg.well_pull
	w.life = cfg.well_life * fuse_duration()
	w.position = pos
	player.get_parent().add_child(w)
