class_name WeaponVenom
extends WeaponBase
## Leaves toxic puddles behind the player while they move. Past Lv3 it lays a wider
## carpet: 1 puddle, +1 at Lv3, +1 at Lv6, spread across the trail (up to 3).

var drop_timer := 0.0


func _init() -> void:
	weapon_id = "venom"
	display_name = "Venom Trail"


func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	drop_timer -= delta
	if drop_timer > 0.0 or player.velocity.length() < 10.0:
		return
	drop_timer = cfg.cd * player.rate_mult  # cd = puddle drop interval
	# Above-Lv3 kicker: lay several puddles abreast (perpendicular to travel) so
	# high levels paint a wide toxic carpet instead of a single-file trail.
	var n := 1
	if level >= 3:
		n += 1
	if level >= 6:
		n += 1
	var perp := player.velocity.normalized().orthogonal()
	for i in n:
		var off: float = (i - (n - 1) / 2.0) * cfg.lane_gap * player.area_mult
		_spawn_puddle(player.global_position + perp * off)
	Sfx.play("venom", player.global_position)


func _spawn_puddle(pos: Vector2) -> void:
	var p := VenomPuddle.new()
	p.source_pid = player.peer_id
	p.source_weapon = self
	p.radius = (cfg.radius_base + cfg.radius_per_level * (level - 1)) * player.area_mult
	p.damage = cfg.dmg * player.damage_mult * (1.0 + cfg.growth * (level - 1))
	p.max_life = cfg.life * player.duration_mult
	p.life = p.max_life
	p.position = pos
	player.get_parent().add_child(p)
