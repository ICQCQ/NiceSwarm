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
	var target := player.nearest_enemy(650.0)
	if target == null:
		cooldown = 0.1
		return
	var base := (target.global_position - player.global_position).normalized()
	var count := 2 + count_level()
	for i in count:
		var g := GlaiveProj.new()
		g.source_pid = player.peer_id
		g.source_weapon = self
		g.player = player
		g.velocity = base.rotated(deg_to_rad(22.0) * (i - (count - 1) / 2.0)) * 430.0
		g.damage = 2.0 * fuse_damage() * (1.0 + 0.3 * (level - 1))
		g.hit_radius = 14.0 * fuse_area()
		g.on_hit = Callable(self, "_on_glaive_hit")
		g.position = player.global_position
		player.get_parent().add_child(g)
	Sfx.play("glaive", player.global_position)
	cooldown = 1.8 * fuse_rate()

## Each glaive hit drops a small gravity well at the hit point, on top of
## the glaive's own direct damage.
func _on_glaive_hit(_e: Node2D, pos: Vector2) -> void:
	var w := GravityWell.new()
	w.source_pid = player.peer_id
	w.source_weapon = self
	w.radius = (50.0 + 6.0 * (level - 1)) * fuse_area()
	w.damage = 0.35 * fuse_damage() * (1.0 + 0.3 * (level - 1))
	w.pull = 120.0
	w.life = 1.0 * fuse_duration()
	w.position = pos
	player.get_parent().add_child(w)
