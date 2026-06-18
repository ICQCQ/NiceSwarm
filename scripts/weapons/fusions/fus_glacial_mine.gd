# --- frost + mines: mines that detonate into a total freeze, halting movement ---
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
	if get_tree().get_nodes_in_group("mines").size() >= cfg.cap_base + count_level():
		cooldown = 0.2
		return
	var dmg: float = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	var m := MineNode.new()
	m.source_pid = player.peer_id
	m.source_weapon = self
	m.damage = dmg
	m.blast_radius = (cfg.blast_radius + cfg.blast_radius_per_count * (count_level() - 1)) * fuse_area()
	m.trigger_radius = cfg.trigger_radius * fuse_area()
	m.life = cfg.life * fuse_duration()
	m.freeze_dur = cfg.freeze_dur_base * fuse_duration()
	m.position = player.global_position \
		+ Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 30.0))
	player.get_parent().add_child(m)
	Sfx.play("mine", player.global_position)
	cooldown = cfg.cd * fuse_rate()
