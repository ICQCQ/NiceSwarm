# --- deployed turret variants (turret + X) -----------------------------------
# Shared deployment mechanics (life/target_range/proj_radius/cd) live in
# WeaponConfig.BASE.sentry; each subclass's own dmg/growth/life_scale/cooldown_scale/
# deploy_cap_bonus live in WeaponConfig.BASE[weapon_id], read dynamically since each
# subclass sets its own weapon_id in _init() before this base class runs.
class_name FusSentryBase
extends WeaponBase

var cooldown := 1.5
var mode := "bolt"
var sentry_cfg: Dictionary  # the shared WeaponConfig.BASE.sentry entry, cached once below
func _ready() -> void:
	super._ready()
	sentry_cfg = WeaponConfig.BASE.sentry
func _deploy_cap() -> int:
	return count_level() + cfg.deploy_cap_bonus
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
	t.life = (sentry_cfg.life_base + sentry_cfg.life_per_level * level) * fuse_duration() * cfg.life_scale
	t.damage = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	t.target_range = sentry_cfg.target_range * fuse_area()
	t.proj_radius = sentry_cfg.proj_radius * fuse_area()
	t.area_mult = fuse_area()
	t.dur_mult = fuse_duration()
	t.fire_mult = fuse_rate()
	t.position = player.global_position
	player.get_parent().add_child(t)
	Sfx.play("turret_deploy", player.global_position)
	# Spread deploys over cd / cap so the field fills to _deploy_cap(); a flat cd
	# was slower than a turret's life, so only ~2 ever coexisted of the cap's many.
	cooldown = sentry_cfg.cd * fuse_rate() * cfg.cooldown_scale / _deploy_cap()
