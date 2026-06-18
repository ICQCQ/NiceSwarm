# --- flame + lightning: emits a drifting cloud that burns on contact and ------
# arcs lightning to nearby enemies ------------------------------------------------
class_name FusPlasmaStorm
extends WeaponBase

var spawn_timer := 0.0
func _init() -> void:
	weapon_id = "fus_plasmastorm"
	display_name = "Plasma Storm"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	spawn_timer -= delta
	if spawn_timer > 0.0:
		return
	if get_tree().get_nodes_in_group("plasma_clouds").size() >= cfg.cap_base + count_level():
		spawn_timer = 0.2
		return
	var dmg: float = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	var ldmg: float = cfg.lightning_dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	# Aim once at whatever's nearest right now — the cloud locks that angle and
	# drifts in a straight line afterward, it never re-tracks the target.
	var target := player.nearest_enemy(cfg.aim_range)
	var dir := Vector2.from_angle(randf() * TAU)
	if target != null:
		dir = (target.global_position - player.global_position).normalized()
	var cloud := PlasmaCloud.new()
	cloud.source_pid = player.peer_id
	cloud.source_weapon = self
	cloud.radius = cfg.radius * fuse_area()             # Area: cloud size
	cloud.max_dist = cfg.max_dist * fuse_duration()      # Duration: max travel distance
	cloud.life = cfg.life * fuse_duration()              # Duration: total lifespan
	cloud.max_life = cloud.life
	cloud.dps = dmg
	cloud.lightning_interval = cfg.lightning_cd * fuse_rate()  # Haste: lightning cadence
	cloud.lightning_dmg = ldmg
	cloud.chain_count = cfg.chain_base + count_level()
	cloud.chain_range = cfg.chain_range * fuse_area()
	cloud.velocity = dir * cfg.speed
	cloud.position = player.global_position
	player.get_parent().add_child(cloud)
	Sfx.play("flame", player.global_position)
	spawn_timer = cfg.spawn_cd * fuse_rate()  # Haste: time between cloud emissions
