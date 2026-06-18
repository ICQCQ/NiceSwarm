class_name WeaponFrost
extends WeaponBase
## Fires a fan of piercing frost shards that slow enemies.

var cooldown := 0.9


func _init() -> void:
	weapon_id = "frost"
	display_name = "Frost Shards"


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
	var base := (target.global_position - player.global_position).normalized()
	var count: int = cfg.count_base + count_level()
	for i in count:
		var s := FrostShard.new()
		s.source_pid = player.peer_id
		s.source_weapon = self
		s.velocity = base.rotated(deg_to_rad(cfg.spread_deg) * (i - (count - 1) / 2.0)) * cfg.speed
		s.damage = cfg.dmg * player.damage_mult * (1.0 + cfg.growth * (level - 1))
		s.hit_radius = cfg.hit_radius * player.area_mult
		s.life = cfg.life * player.duration_mult
		s.slow_dur = cfg.slow_dur * player.duration_mult  # Duration extends the chill
		s.position = player.global_position
		player.get_parent().add_child(s)
	Sfx.play("frost", player.global_position)
	cooldown = cfg.cd * player.rate_mult
