# --- bolt + flame: bolts that drop a burning puddle on impact ----------------
class_name FusIncendiaryRounds
extends WeaponBase

var cooldown := 0.45
func _init() -> void:
	weapon_id = "fus_incendiary"
	display_name = "Incendiary Rounds"
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
	var base_dir := (target.global_position - player.global_position).normalized()
	var count := 1 + count_level()
	var dmg := 1.8 * fuse_damage() * (1.0 + 0.35 * (level - 1))
	var puddle_r := (50.0 + 8.0 * (level - 1)) * fuse_area()
	var puddle_life := 2.5 * fuse_duration()
	for i in count:
		var spread := deg_to_rad(9.0) * (i - (count - 1) / 2.0)
		var p := Projectile.new()
		p.source_pid = player.peer_id
		p.source_weapon = self
		p.velocity = base_dir.rotated(spread) * 500.0
		p.damage = dmg
		p.radius = 6.0 * fuse_area()
		p.life = 1.6 * fuse_duration()
		p.color = Color(1.0, 0.55, 0.15)
		p.fire_puddle_radius = puddle_r
		p.fire_puddle_damage = 0.6 * fuse_damage() * (1.0 + 0.3 * (level - 1))
		p.fire_puddle_life = puddle_life
		p.fire_puddle_burn_dps = 0.9 * fuse_damage() * (1.0 + 0.3 * (level - 1))
		p.fire_puddle_burn_dur = 1.5 * fuse_duration()
		p.fire_puddle_source_pid = player.peer_id
		p.fire_puddle_source_weapon = self
		p.position = player.global_position
		player.get_parent().add_child(p)
	Sfx.play("bolt", player.global_position)
	cooldown = 0.85 * fuse_rate()
