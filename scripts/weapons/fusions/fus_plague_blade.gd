# --- glaive + venom: boomerangs that poison and leave toxic pools ------------
class_name FusPlagueBlade
extends WeaponBase

var cooldown := 1.0
func _init() -> void:
	weapon_id = "fus_plagueblade"
	display_name = "Plague Blade"
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
	var count: int = cfg.count_base + count_level()
	var base := (target.global_position - player.global_position).normalized()
	var dmg: float = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	for i in count:
		var g := GlaiveProj.new()
		g.source_pid = player.peer_id
		g.source_weapon = self
		g.player = player
		g.velocity = base.rotated(deg_to_rad(cfg.spread_deg) * (i - (count - 1) / 2.0)) * cfg.speed
		g.damage = dmg
		g.burn_dps = dmg * cfg.burn_dps_ratio
		g.hit_radius = cfg.hit_radius * fuse_area()
		g.on_hit = Callable(self, "_on_hit")
		g.position = player.global_position
		player.get_parent().add_child(g)
	Sfx.play("venom", player.global_position)
	cooldown = cfg.cd * fuse_rate()

## Each glaive hit leaves a small toxic pool behind it.
func _on_hit(_e: Node2D, pos: Vector2) -> void:
	var pud := VenomPuddle.new()
	pud.source_pid = player.peer_id
	pud.source_weapon = self
	pud.radius = (cfg.puddle_radius + cfg.puddle_radius_per_level * (level - 1)) * fuse_area()
	pud.damage = cfg.puddle_dmg * fuse_damage() * (1.0 + cfg.secondary_growth * (level - 1))
	pud.max_life = cfg.puddle_life * fuse_duration()
	pud.life = pud.max_life
	pud.position = pos
	player.get_parent().add_child(pud)
