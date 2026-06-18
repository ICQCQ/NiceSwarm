# --- missiles + orbit: a paper-plane missile that never dies at the border, --
# warping to a new side of the arena and re-aiming at the player instead --------
class_name FusConcorde
extends WeaponBase

var cooldown := 8.0
func _init() -> void:
	weapon_id = "fus_concorde"
	display_name = "Concorde"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	var target := player.nearest_enemy(cfg.range)
	var dir := Vector2.from_angle(randf() * TAU)
	if target != null:
		dir = (target.global_position - player.global_position).normalized()
	# No population cap — a long cooldown + its own long lifetime are the only leash.
	var m := ConcordeMissile.new()
	m.source_pid = player.peer_id
	m.source_weapon = self
	m.player_ref = player
	m.direction = dir
	m.speed = cfg.speed
	m.speed_ramp = cfg.speed_ramp
	m.dmg = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	m.dmg_ramp = cfg.dmg_ramp
	m.max_size = cfg.max_size * fuse_area()      # Area: max size it grows to
	m.life = cfg.life * fuse_duration() * 1.5           # Duration: greatly extends lifetime
	m.position = player.global_position
	player.get_parent().add_child(m)
	Sfx.play("concorde", player.global_position)
	cooldown = cfg.cd * fuse_rate()  # Haste: long base cooldown between launches
