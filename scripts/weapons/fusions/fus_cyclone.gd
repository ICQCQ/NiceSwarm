# --- glaive + nova -----------------------------------------------------------
class_name FusCyclone
extends WeaponBase

var cooldown := 0.8
var nova_cd := 0.0
func _init() -> void:
	weapon_id = "fus_cyclone"
	display_name = "Cyclone"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	cooldown -= delta
	if cooldown <= 0.0:
		var target := player.nearest_enemy(cfg.range)
		if target != null:
			var count: int = cfg.count_base + count_level()
			var base := (target.global_position - player.global_position).normalized()
			for i in count:
				var g := GlaiveProj.new()
				g.source_pid = player.peer_id
				g.source_weapon = self
				g.player = player
				g.velocity = base.rotated(TAU * float(i) / count) * cfg.glaive_speed
				g.damage = 0.0
				g.hit_radius = cfg.glaive_hit_radius * fuse_area()
				g.on_hit = Callable(self, "_on_glaive_hit")
				g.position = player.global_position
				player.get_parent().add_child(g)
			Sfx.play("glaive", player.global_position)
			cooldown = cfg.cd * fuse_rate()
		else:
			cooldown = 0.1
	nova_cd -= delta
	if nova_cd <= 0.0:
		var radius: float = (cfg.nova_radius_base + cfg.nova_radius_per_count * (count_level() - 1)) * fuse_area()  # central nova back to good area
		var ndmg: float = cfg.nova_dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
		var any := false
		for e in Main.instance.enemies_in_radius(player.global_position, radius + 64.0):
			if player.global_position.distance_to(e.global_position) <= radius + e.radius:
				damage_dealt += ndmg
				e.take_hit(ndmg, player.global_position, Enemy.DMG_ENERGY, player.peer_id)
				ignite(e, ndmg)
				push(e, player.global_position)
				any = true
		if any:
			var fx := RingFx.new()
			fx.position = player.global_position
			fx.radius = 25.0
			fx.max_radius = radius
			fx.life = 0.35
			fx.color = Color(0.7, 0.9, 1.0)
			player.get_parent().add_child(fx)
			Sfx.play("nova", player.global_position)
			nova_cd = cfg.nova_cd * fuse_rate()
		else:
			nova_cd = 0.3

## Each glaive hit triggers a small energy burst at the hit point instead
## of dealing direct damage.
func _on_glaive_hit(_e: Node2D, pos: Vector2) -> void:
	var radius: float = cfg.burst_radius * fuse_area()  # bigger nova-burst on each blade hit, not a mini bang
	var dmg: float = cfg.burst_dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	for en in EnemyGrid.near(pos, radius):
		if pos.distance_to(en.global_position) <= radius + en.radius:
			damage_dealt += dmg
			en.take_hit(dmg, pos, Enemy.DMG_ENERGY, player.peer_id)
			ignite(en, dmg)
	var fx := RingFx.new()
	fx.position = pos
	fx.radius = 8.0
	fx.max_radius = radius
	fx.life = 0.25
	fx.color = Color(0.7, 0.9, 1.0)
	player.get_parent().add_child(fx)
