# --- bolt + mines: bolt arms a proximity mine on impact ----------------------
class_name FusSapperRound
extends WeaponBase

var cooldown := 0.5
func _init() -> void:
	weapon_id = "fus_sapper"
	display_name = "Sapper Round"
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
	var dmg := 1.5 * fuse_damage() * (1.0 + 0.35 * (level - 1))
	for i in level:
		var spread := deg_to_rad(10.0) * (i - (level - 1) / 2.0)
		var p := Projectile.new()
		p.source_pid = player.peer_id
		p.source_weapon = self
		p.velocity = dir.rotated(spread) * 500.0
		p.damage = dmg
		p.radius = 5.0 * fuse_area()
		p.life = 1.6 * fuse_duration()
		p.color = Color(0.85, 0.75, 0.3)
		p.on_hit = Callable(self, "_arm_mine")
		p.position = player.global_position
		player.get_parent().add_child(p)
	Sfx.play("bolt", player.global_position)
	cooldown = 0.9 * fuse_rate()
func _arm_mine(_enemy: Node2D, hit_pos: Vector2, world: Node) -> void:
	if player == null:
		return
	var m := MineNode.new()
	m.source_pid = player.peer_id
	m.source_weapon = self
	m.damage = 5.0 * fuse_damage() * (1.0 + 0.4 * (level - 1))
	m.blast_radius = (90.0 + 12.0 * (level - 1)) * fuse_area()
	m.trigger_radius = 50.0 * fuse_area()
	m.life = 8.0 * fuse_duration()
	m.position = hit_pos
	world.add_child(m)
	Sfx.play("mine", hit_pos, -4.0)
