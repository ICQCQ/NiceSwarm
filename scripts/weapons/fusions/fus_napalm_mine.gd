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
	if owned_in_group("mines") >= 3 + level:  # per-weapon cap, not a shared global count
		cooldown = 0.2
		return
	var dmg := 6.0 * fuse_damage() * (1.0 + 0.5 * (level - 1))
	var m := MineNode.new()
	m.source_pid = player.peer_id
	m.source_weapon = self
	m.owner_weapon_id = get_instance_id()
	m.damage = dmg
	m.blast_radius = (100.0 + 15.0 * (level - 1)) * fuse_area()
	m.trigger_radius = 55.0 * fuse_area()
	m.life = 12.0 * fuse_duration()
	m.fire_dps = dmg * 0.25
	m.fire_radius = 90.0 * fuse_area()
	m.fire_dur = 2.0 * fuse_duration()
	m.position = player.global_position \
		+ Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 30.0))
	player.get_parent().add_child(m)
	Sfx.play("mine", player.global_position)
	cooldown = 2.0 * fuse_rate()
