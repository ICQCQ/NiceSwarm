# --- bolt + missiles ---------------------------------------------------------
class_name FusBarrage
extends WeaponBase

var cooldown := 0.3
func _init() -> void:
	weapon_id = "fus_barrage"
	display_name = "Flak Battery"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	var target := player.nearest_enemy(700.0)
	if target == null:
		cooldown = 0.1
		return
	var base := (target.global_position - player.global_position).normalized()
	var count := 1 + count_level()
	var dmg := 1.0 * fuse_damage() * (1.0 + 0.3 * (level - 1))
	var splash := (36.0 + 6.0 * (level - 1)) * fuse_area()
	for i in count:
		var p := Projectile.new()
		p.source_pid = player.peer_id
		p.source_weapon = self
		p.velocity = base.rotated(deg_to_rad(14.0) * (i - (count - 1) / 2.0)) * 480.0
		p.damage = dmg * 0.4
		p.radius = 4.0 * fuse_area()
		p.life = 1.8 * fuse_duration()
		p.explode_radius = splash  # every shot is a self-propelled flak shell
		p.explode_damage = dmg
		p.homing_turn = 5.0  # curves toward the nearest enemy as it flies
		p.homing_range = 260.0 * fuse_area()
		p.color = Color(1.0, 0.7, 0.3)
		p.position = player.global_position
		player.get_parent().add_child(p)
	Sfx.play("missile", player.global_position, -6.0)
	cooldown = 0.5 * fuse_rate()
