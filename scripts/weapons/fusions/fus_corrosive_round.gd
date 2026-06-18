# --- bolt + venom: bolt poisons target + leaves a venom pool -----------------
class_name FusCorrosiveRound
extends WeaponBase

var cooldown := 0.5
func _init() -> void:
	weapon_id = "fus_corrosive"
	display_name = "Corrosive Round"
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
	var dir := (target.global_position - player.global_position).normalized()
	var dmg: float = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	var count := count_level()  # near-max salvo at birth (count_level floors for fresh fusions), capped at MAX
	for i in count:
		var spread := deg_to_rad(cfg.spread_deg) * (i - (count - 1) / 2.0)
		var p := Projectile.new()
		p.source_pid = player.peer_id
		p.source_weapon = self
		p.velocity = dir.rotated(spread) * cfg.speed
		p.damage = dmg
		p.radius = cfg.radius * fuse_area()
		p.life = cfg.life * fuse_duration()
		p.color = Color(0.45, 0.9, 0.35)
		p.on_hit = Callable(self, "_corrode")
		p.position = player.global_position
		player.get_parent().add_child(p)
	Sfx.play("bolt", player.global_position)
	cooldown = cfg.cd * fuse_rate()
func _corrode(enemy: Node2D, hit_pos: Vector2, world: Node) -> void:
	if player == null:
		return
	enemy.apply_burn(cfg.burn_dmg * fuse_damage() * (1.0 + cfg.burn_growth * (level - 1)), cfg.burn_dur * fuse_duration(), 1.0, player.peer_id)
	var pud := VenomPuddle.new()
	pud.source_pid = player.peer_id
	pud.source_weapon = self
	pud.radius = (cfg.pool_radius_base + cfg.pool_radius_per_level * (level - 1)) * fuse_area()
	pud.damage = cfg.pool_dmg * fuse_damage() * (1.0 + cfg.pool_growth * (level - 1))
	pud.max_life = cfg.pool_life * fuse_duration()
	pud.life = pud.max_life
	pud.position = hit_pos
	world.add_child(pud)
	Sfx.play("venom", hit_pos, -6.0)
