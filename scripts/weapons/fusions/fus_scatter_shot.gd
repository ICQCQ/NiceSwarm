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
	var count := 6 + 2 * count_level()  # born ~18 bolts (count_level floored), 20 at max
	var dmg := 4.1 * fuse_damage() * (1.0 + GameConfig.FUSION_LEVEL_GROWTH * (level - 1))
	for i in count:
		var dir := Vector2.from_angle(TAU * float(i) / count)
		var p := Projectile.new()
		p.source_pid = player.peer_id
		p.source_weapon = self
		p.velocity = dir * 480.0
		p.damage = dmg
		p.radius = 5.5 * fuse_area()
		p.life = 1.5 * fuse_duration()
		p.color = Color(0.9, 0.8, 0.3)
		p.position = player.global_position
		player.get_parent().add_child(p)
	Sfx.play("bolt", player.global_position)
	cooldown = 2.2 * fuse_rate()
