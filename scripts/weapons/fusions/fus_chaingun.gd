# --- bolt + laser: rapid single-bolt stream ----------------------------------
class_name FusChaingun
extends WeaponBase

var cooldown := 0.2
func _init() -> void:
	weapon_id = "fus_chaingun"
	display_name = "Chaingun"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	var target := player.nearest_enemy(680.0)
	if target == null:
		cooldown = 0.08
		return
	var dir := (target.global_position - player.global_position).normalized()
	dir = dir.rotated(randf_range(-0.07, 0.07))
	var p := Projectile.new()
	p.source_pid = player.peer_id
	p.source_weapon = self
	p.velocity = dir * 600.0
	p.damage = 0.75 * fuse_damage() * (1.0 + 0.4 * (level - 1))
	p.radius = 4.0 * fuse_area()
	p.life = 1.5 * fuse_duration()
	p.color = Color(0.8, 0.95, 1.0)
	p.position = player.global_position
	player.get_parent().add_child(p)
	Sfx.play("bolt", player.global_position, -7.0)
	cooldown = 0.2 * fuse_rate()
