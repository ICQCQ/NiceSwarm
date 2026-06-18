# --- flame + mines -----------------------------------------------------------
class_name FusNapalmMine
extends WeaponBase

var cooldown := 1.1
func _init() -> void:
	weapon_id = "fus_napalm"
	display_name = "Napalm Mine"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	if owned_in_group("mines") >= cfg.cap_base + count_level():  # per-weapon cap, not a shared global count
		cooldown = 0.2
		return
	var dmg: float = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	var m := MineNode.new()
	m.source_pid = player.peer_id
	m.source_weapon = self
	m.owner_weapon_id = get_instance_id()
	m.damage = dmg
	m.blast_radius = (cfg.blast_radius + cfg.blast_radius_per_count * (count_level() - 1)) * fuse_area()
	m.trigger_radius = cfg.trigger_radius * fuse_area()
	m.life = cfg.life * fuse_duration()
	m.fire_dps = dmg * cfg.fire_dps_ratio
	m.fire_radius = cfg.fire_radius * fuse_area()
	m.fire_dur = cfg.fire_dur * fuse_duration()
	m.position = player.global_position \
		+ Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 30.0))
	player.get_parent().add_child(m)
	Sfx.play("mine", player.global_position)
	cooldown = cfg.cd * fuse_rate()
