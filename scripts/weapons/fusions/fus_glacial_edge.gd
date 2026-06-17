# --- frost + glaive ----------------------------------------------------------
class_name FusGlacialEdge
extends WeaponBase

var cooldown := 0.8
func _init() -> void:
	weapon_id = "fus_glacial"
	display_name = "Glacial Edge"
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
	var count := 2 + count_level()
	var base := (target.global_position - player.global_position).normalized()
	var dmg := 5.1 * fuse_damage() * (1.0 + GameConfig.FUSION_LEVEL_GROWTH * (level - 1))
	for i in count:
		var g := GlaiveProj.new()
		g.source_pid = player.peer_id
		g.source_weapon = self
		g.player = player
		g.velocity = base.rotated(deg_to_rad(22.0) * (i - (count - 1) / 2.0)) * 430.0
		g.damage = dmg * 0.6
		g.burn_dps = dmg * 0.3
		g.hit_radius = 15.0 * fuse_area()
		g.slow_factor = 0.5
		g.position = player.global_position
		player.get_parent().add_child(g)
	Sfx.play("frost", player.global_position)
	cooldown = 1.5 * fuse_rate()
