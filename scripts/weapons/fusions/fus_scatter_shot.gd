# --- bolt + orbit: ring of bolts in all directions ---------------------------
class_name FusScatterShot
extends WeaponBase

var cooldown := 1.5
func _init() -> void:
	weapon_id = "fus_scatter"
	display_name = "Scatter Shot"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	var count: int = cfg.count_base + cfg.count_per_level * count_level()  # born ~18 bolts (count_level floored), 20 at max
	var dmg: float = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	for i in count:
		var dir := Vector2.from_angle(TAU * float(i) / count)
		var p := Projectile.new()
		p.source_pid = player.peer_id
		p.source_weapon = self
		p.velocity = dir * cfg.speed
		p.damage = dmg
		p.radius = cfg.radius * fuse_area()
		p.life = cfg.life * fuse_duration()
		p.color = Color(0.9, 0.8, 0.3)
		p.position = player.global_position
		player.get_parent().add_child(p)
	Sfx.play("bolt", player.global_position)
	cooldown = cfg.cd * fuse_rate()
