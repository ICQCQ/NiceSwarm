# --- glaive + lightning ------------------------------------------------------
class_name FusStormDisc
extends WeaponBase

var cooldown := 0.9
func _init() -> void:
	weapon_id = "fus_storm"
	display_name = "Storm Disc"
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
	var count := 1 + count_level()
	var base := (target.global_position - player.global_position).normalized()
	var dmg := 5.1 * fuse_damage() * (1.0 + GameConfig.FUSION_LEVEL_GROWTH * (level - 1))
	for i in count:
		var g := GlaiveProj.new()
		g.source_pid = player.peer_id
		g.source_weapon = self
		g.player = player
		g.velocity = base.rotated(deg_to_rad(24.0) * (i - (count - 1) / 2.0)) * 430.0
		g.damage = dmg * 0.6
		g.burn_dps = dmg * 0.3
		g.hit_radius = 14.0 * fuse_area()
		g.arc_damage = dmg * 0.6
		g.arc_range = 150.0 * fuse_area()
		g.position = player.global_position
		player.get_parent().add_child(g)
	Sfx.play("lightning", player.global_position)
	cooldown = 1.6 * fuse_rate()
