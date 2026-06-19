# --- lightning + mines: mines placed inert -- they project a continuous -----
# --- shocking field, then arm like a normal mine once inert_dur runs out ----
class_name FusTeslaMine
extends WeaponBase

var cooldown := 1.1
func _init() -> void:
	weapon_id = "fus_teslamine"
	display_name = "Tesla Mine"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	if owned_in_group("tesla_mines") >= cfg.cap_base + count_level():
		cooldown = 0.2
		return
	var m := TeslaMineNode.new()
	m.source_pid = player.peer_id
	m.source_weapon = self
	m.owner_weapon_id = get_instance_id()
	m.chain_count = cfg.chain_count_base + count_level()
	m.chain_range = cfg.chain_range * fuse_area()
	m.dmg = cfg.chain_dmg * fuse_damage() * (1.0 + cfg.chain_growth * (level - 1))
	m.shock_interval = cfg.shock_interval * fuse_rate()
	m.life = cfg.life * fuse_duration()
	m.inert_period = cfg.inert_dur * fuse_duration()
	m.blast_dmg = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	m.blast_radius = (cfg.blast_radius + cfg.blast_radius_per_count * (count_level() - 1)) * fuse_area()
	m.trigger_radius = cfg.trigger_radius * fuse_area()
	m.position = player.global_position \
		+ Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 30.0))
	player.get_parent().add_child(m)
	Sfx.play("mine", player.global_position)
	cooldown = cfg.cd * fuse_rate()
