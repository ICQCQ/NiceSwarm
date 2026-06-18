# --- shared mine-fusion helper: drop a proximity mine with a bonus payload ---
# Base mine stats (dmg/growth/cd/blast_radius/trigger_radius/life/cap_base) live per
# subclass in WeaponConfig.BASE[weapon_id], read dynamically since each subclass sets
# its own weapon_id in _init() before this base class runs.
class_name FusMineBase
extends WeaponBase

var cooldown := 1.1
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	if get_tree().get_nodes_in_group("mines").size() >= cfg.cap_base + count_level():
		cooldown = 0.2
		return
	var m := MineNode.new()
	m.source_pid = player.peer_id
	m.source_weapon = self
	m.damage = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))  # mine = mines @L7 (26.7 eff)
	m.blast_radius = (cfg.blast_radius + cfg.blast_radius_per_count * (count_level() - 1)) * fuse_area()  # born ~184, max ~190 = mines @L7 blast
	m.trigger_radius = cfg.trigger_radius * fuse_area()
	m.life = cfg.life * fuse_duration()
	_load(m)
	m.position = player.global_position \
		+ Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 30.0))
	player.get_parent().add_child(m)
	Sfx.play("mine", player.global_position)
	cooldown = cfg.cd * fuse_rate()
## Override: add the fused payload. Payload power uses (level + 1), i.e. the
## component the mine spawns on blast is one level above the mine itself.
func _load(_m: MineNode) -> void:
	pass
