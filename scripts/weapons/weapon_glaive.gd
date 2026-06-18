class_name WeaponGlaive
extends WeaponBase
## Boomerang glaive thrower. Glaives in the fan grow with level: 1 at Lv1, 2 at
## Lv2, then +1 every level (3 at Lv3 … 7 at Lv7), frozen past the count cap.

var cooldown := 0.8


func _init() -> void:
	weapon_id = "glaive"
	display_name = "Glaive"


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
	var count := 1
	if level >= 2:
		count += 1
	if level >= 3:
		count += count_level() - (3 - 1)
	var base := (target.global_position - player.global_position).normalized()
	for i in count:
		var g := GlaiveProj.new()
		g.source_pid = player.peer_id
		g.source_weapon = self
		g.player = player
		g.velocity = base.rotated(deg_to_rad(cfg.spread_deg) * (i - (count - 1) / 2.0)) * (cfg.speed * (1.0 + cfg.speed_growth * (level - 1)))  # speed grows with level (range = v^2/2decel grows too)
		g.damage = cfg.dmg * player.damage_mult * (1.0 + cfg.growth * (level - 1))
		g.burn_dps = g.damage * 0.3
		g.hit_radius = cfg.hit_radius * player.area_mult
		g.position = player.global_position
		player.get_parent().add_child(g)
	Sfx.play("glaive", player.global_position)
	cooldown = cfg.cd * player.rate_mult
