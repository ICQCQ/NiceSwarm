# --- shared mine-fusion helper: drop a proximity mine with a bonus payload ---
class_name FusMineBase
extends WeaponBase

var cooldown := 1.1
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	if get_tree().get_nodes_in_group("mines").size() >= 3 + count_level():
		cooldown = 0.2
		return
	var m := MineNode.new()
	m.source_pid = player.peer_id
	m.source_weapon = self
	m.damage = 17.8 * fuse_damage() * (1.0 + GameConfig.FUSION_LEVEL_GROWTH * (level - 1))  # mine = mines @L7 (26.7 eff)
	m.blast_radius = (154.0 + 6.0 * (count_level() - 1)) * fuse_area()  # born ~184, max ~190 = mines @L7 blast
	m.trigger_radius = 50.0 * fuse_area()
	m.life = 11.0 * fuse_duration()
	_load(m)
	m.position = player.global_position \
		+ Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 30.0))
	player.get_parent().add_child(m)
	Sfx.play("mine", player.global_position)
	cooldown = 1.9 * fuse_rate()
## Override: add the fused payload. Payload power uses (level + 1), i.e. the
## component the mine spawns on blast is one level above the mine itself.
func _load(_m: MineNode) -> void:
	pass
