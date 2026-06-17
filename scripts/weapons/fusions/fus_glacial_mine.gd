# --- frost + mines: mines that freeze all enemies in the blast ---------------
class_name FusGlacialMine
extends WeaponBase

var cooldown := 1.2
func _init() -> void:
	weapon_id = "fus_glacmine"
	display_name = "Glacial Mine"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	if get_tree().get_nodes_in_group("mines").size() >= 3 + count_level():
		cooldown = 0.2
		return
	var dmg := 5.0 * fuse_damage() * (1.0 + 0.4 * (level - 1))
	var m := MineNode.new()
	m.source_pid = player.peer_id
	m.source_weapon = self
	m.damage = dmg
	m.blast_radius = (154.0 + 6.0 * (count_level() - 1)) * fuse_area()
	m.trigger_radius = 55.0 * fuse_area()
	m.life = 12.0 * fuse_duration()
	m.freeze_slow = 0.5
	m.freeze_dur = dmg * 0.4 * fuse_duration()
	m.position = player.global_position \
		+ Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 30.0))
	player.get_parent().add_child(m)
	Sfx.play("mine", player.global_position)
	cooldown = 2.2 * fuse_rate()
