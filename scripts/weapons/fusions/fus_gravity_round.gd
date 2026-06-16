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
	var target := player.nearest_enemy(650.0)
	if target == null:
		cooldown = 0.1
		return
	var dir := (target.global_position - player.global_position).normalized()
	var dmg := 2.8 * fuse_damage() * (1.0 + 0.4 * (level - 1))
	for i in level:
		var spread := deg_to_rad(9.0) * (i - (level - 1) / 2.0)
		var p := Projectile.new()
		p.source_pid = player.peer_id
		p.source_weapon = self
		p.velocity = dir.rotated(spread) * 500.0
		p.damage = dmg
		p.radius = 5.5 * fuse_area()
		p.life = 1.6 * fuse_duration()
		p.color = Color(0.7, 0.5, 1.0)
		p.on_hit = Callable(self, "_spawn_well")
		p.position = player.global_position
		player.get_parent().add_child(p)
	Sfx.play("bolt", player.global_position)
	cooldown = 1.1 * fuse_rate()
func _spawn_well(_enemy: Node2D, hit_pos: Vector2, world: Node) -> void:
	if player == null:
		return
	var w := GravityWell.new()
	w.source_pid = player.peer_id
	w.source_weapon = self
	w.radius = (80.0 + 10.0 * (level - 1)) * fuse_area()
	w.damage = 0.5 * fuse_damage() * (1.0 + 0.3 * (level - 1))
	w.pull = 220.0
	w.life = 1.5 * fuse_duration()
	w.position = hit_pos
	world.add_child(w)
	Sfx.play("gravity", hit_pos, -6.0)
