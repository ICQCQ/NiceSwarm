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
		p.color = Color(0.85, 0.75, 0.3)
		p.on_hit = Callable(self, "_arm_mine")
		p.position = player.global_position
		player.get_parent().add_child(p)
	Sfx.play("bolt", player.global_position)
	cooldown = cfg.cd * fuse_rate()
func _arm_mine(_enemy: Node2D, hit_pos: Vector2, world: Node) -> void:
	if player == null:
		return
	var m := MineNode.new()
	m.source_pid = player.peer_id
	m.source_weapon = self
	m.damage = cfg.mine_dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	m.blast_radius = (cfg.blast_radius + cfg.blast_radius_per_level * (level - 1)) * fuse_area()
	m.trigger_radius = cfg.trigger_radius * fuse_area()
	m.life = cfg.mine_life * fuse_duration()
	m.position = hit_pos
	world.add_child(m)
	Sfx.play("mine", hit_pos, -4.0)
