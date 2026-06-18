# --- bolt + flame: bolts that drop a burning puddle on impact ----------------
class_name FusIncendiaryRounds
extends WeaponBase

var cooldown := 0.45
func _init() -> void:
	weapon_id = "fus_incendiary"
	display_name = "Incendiary Rounds"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	var target := player.nearest_enemy(cfg.range)
	if target == null:
		cooldown = 0.1
		return
	var base_dir := (target.global_position - player.global_position).normalized()
	var count: int = cfg.count_base + count_level()
	var dmg: float = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	var puddle_r: float = (cfg.puddle_radius + cfg.puddle_radius_per_level * (level - 1)) * fuse_area()
	var puddle_life: float = cfg.puddle_life * fuse_duration()
	for i in count:
		var spread := deg_to_rad(cfg.spread_deg) * (i - (count - 1) / 2.0)
		var p := Projectile.new()
		p.source_pid = player.peer_id
		p.source_weapon = self
		p.velocity = base_dir.rotated(spread) * cfg.speed
		p.damage = dmg
		p.radius = cfg.radius * fuse_area()
		p.life = cfg.life * fuse_duration()
		p.color = Color(1.0, 0.55, 0.15)
		p.fire_puddle_radius = puddle_r
		p.fire_puddle_damage = cfg.puddle_dmg * fuse_damage() * (1.0 + cfg.secondary_growth * (level - 1))
		p.fire_puddle_life = puddle_life
		p.fire_puddle_burn_dps = cfg.burn_dps * fuse_damage() * (1.0 + cfg.secondary_growth * (level - 1))
		p.fire_puddle_burn_dur = cfg.burn_dur * fuse_duration()
		p.fire_puddle_source_pid = player.peer_id
		p.fire_puddle_source_weapon = self
		p.position = player.global_position
		player.get_parent().add_child(p)
	Sfx.play("bolt", player.global_position)
	cooldown = cfg.cd * fuse_rate()
