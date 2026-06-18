# --- missiles + nova: straight-flying warheads that erupt into a heavy --------
# shockwave on impact, shoving everything in the blast outward -------------------
class_name FusClusterWarhead
extends WeaponBase

var cooldown := 1.4
func _init() -> void:
	weapon_id = "fus_warhead"
	display_name = "Cluster Warhead"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	var candidates := Main.instance.enemies_in_radius(player.global_position, cfg.range * fuse_area())
	if candidates.is_empty():
		cooldown = 0.2
		return
	var count: int = cfg.count_base + count_level()
	var dmg: float = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	var explode_dmg: float = cfg.explode_dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	var push_dist: float = cfg.push_dist * fuse_duration()  # Duration: how far the blast shoves enemies
	# Fired all at once, but each warhead picks its own random nearby target —
	# they fan out toward different foes instead of clustering on one direction.
	for i in count:
		var pick: Node2D = candidates[randi() % candidates.size()]
		var dir := (pick.global_position - player.global_position).normalized()
		var p := Projectile.new()
		p.source_pid = player.peer_id
		p.source_weapon = self
		p.velocity = dir * cfg.speed
		p.damage = dmg
		p.radius = cfg.radius * fuse_area()
		p.life = cfg.life * fuse_duration()
		p.color = Color(1.0, 0.45, 0.2)  # explosion-flash tint, not the body (see Projectile._draw)
		p.missile_look = true
		p.explode_radius = cfg.splash * fuse_area()
		p.explode_damage = explode_dmg
		p.blast_push_dist = push_dist
		p.position = player.global_position
		player.get_parent().add_child(p)
	Sfx.play("missile", player.global_position)
	cooldown = cfg.cd * fuse_rate()
