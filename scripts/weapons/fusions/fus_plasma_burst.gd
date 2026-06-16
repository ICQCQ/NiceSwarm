# --- bolt + nova -------------------------------------------------------------
class_name FusPlasmaBurst
extends WeaponBase

var cooldown := 0.6
func _init() -> void:
	weapon_id = "fus_plasma"
	display_name = "Plasma Burst"
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
	var n := 1 + count_level()
	var dmg := 2.0 * fuse_damage() * (1.0 + 0.4 * (level - 1))
	for i in n:
		var p := Projectile.new()
		p.source_pid = player.peer_id
		p.source_weapon = self
		p.velocity = dir.rotated(deg_to_rad(8.0) * (i - (n - 1) / 2.0)) * 480.0
		p.damage = dmg
		p.radius = 7.0 * fuse_area()
		p.life = 1.6 * fuse_duration()
		p.explode_radius = 100.0 * fuse_area()  # the bolt blooms a real nova ring, not a pop
		p.explode_damage = dmg * 0.8
		p.push_strength = 70.0 * fuse_area()
		p.color = Color(1.0, 0.5, 0.9)
		p.position = player.global_position
		player.get_parent().add_child(p)
	Sfx.play("nova", player.global_position)
	cooldown = 0.9 * fuse_rate()
