# --- deployed turret variants (turret + X) -----------------------------------
class_name FusSentryBase
extends WeaponBase

var cooldown := 1.5
var mode := "bolt"
var dmg_base := WeaponConfig.BASE.sentry.dmg
var life_scale := 1.0      # fused Gatling Nest: shorter-lived, faster-redeploying turrets
var cooldown_scale := 1.0
func _deploy_cap() -> int:
	return count_level() + 2
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	var mine := 0
	for tn in get_tree().get_nodes_in_group("turrets"):
		if tn.owner_weapon_id == get_instance_id():
			mine += 1
	if mine >= _deploy_cap():
		cooldown = 0.3
		return
	var t := TurretNode.new()
	t.owner_weapon_id = get_instance_id()
	t.source_pid = player.peer_id
	t.source_weapon = self
	t.mode = mode
	t.life = (6.0 + 0.5 * level) * fuse_duration() * life_scale
	t.damage = dmg_base * fuse_damage() * (1.0 + GameConfig.FUSION_LEVEL_GROWTH * (level - 1))
	t.target_range = 480.0 * fuse_area()
	t.proj_radius = 5.0 * fuse_area()
	t.area_mult = fuse_area()
	t.dur_mult = fuse_duration()
	t.fire_mult = fuse_rate()
	t.position = player.global_position
	player.get_parent().add_child(t)
	Sfx.play("turret_deploy", player.global_position)
	# Spread deploys over cd / cap so the field fills to _deploy_cap(); a flat cd
	# was slower than a turret's life, so only ~2 ever coexisted of the cap's many.
	cooldown = WeaponConfig.BASE.sentry.cd * fuse_rate() * cooldown_scale / _deploy_cap()
