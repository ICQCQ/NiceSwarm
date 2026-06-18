# --- bolt + missiles ---------------------------------------------------------
class_name FusBarrage
extends WeaponBase

var cooldown := 0.3
func _init() -> void:
	weapon_id = "fus_barrage"
	display_name = "Flak Battery"
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
	var dmg: float = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	var splash: float = (cfg.splash_base + cfg.splash_per_level * (level - 1)) * fuse_area()
	for i in count:
		var p := Projectile.new()
		p.source_pid = player.peer_id
		p.source_weapon = self
		p.velocity = base.rotated(deg_to_rad(cfg.spread_deg) * (i - (count - 1) / 2.0)) * cfg.speed
		p.damage = dmg * cfg.direct_dmg_ratio
		p.radius = cfg.radius * fuse_area()
		p.life = cfg.life * fuse_duration()
		p.explode_radius = splash  # every shot is a self-propelled flak shell
		p.explode_damage = dmg
		p.homing_turn = cfg.homing_turn  # curves toward the nearest enemy as it flies
		p.homing_range = cfg.homing_range * fuse_area()
		p.color = Color(1.0, 0.7, 0.3)
		p.position = player.global_position
		player.get_parent().add_child(p)
	Sfx.play("missile", player.global_position, -6.0)
	cooldown = cfg.cd * fuse_rate()
