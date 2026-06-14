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
	var target := player.nearest_enemy(650.0)
	if target == null:
		cooldown = 0.1
		return
	var base := (target.global_position - player.global_position).normalized()
	var count := 2 + level
	for i in count:
		var s := FrostShard.new()
		s.source_pid = player.peer_id
		s.velocity = base.rotated(deg_to_rad(8.0) * (i - (count - 1) / 2.0)) * 480.0
		s.damage = WeaponConfig.BASE.frost.dmg * player.damage_mult * (1.0 + WeaponConfig.BASE.frost.growth * (level - 1))
		s.hit_radius = 7.0 * player.area_mult
		s.life = 1.4 * player.duration_mult
		s.slow_dur = 1.5 * player.duration_mult  # Duration extends the chill
		s.position = player.global_position
		player.get_parent().add_child(s)
	Sfx.play("frost", player.global_position)
	cooldown = WeaponConfig.BASE.frost.cd * player.rate_mult
