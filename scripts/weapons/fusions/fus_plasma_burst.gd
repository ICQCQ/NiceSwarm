# --- bolt + nova -------------------------------------------------------------
class_name FusPlasmaBurst
extends WeaponBase

var cooldown := 0.6
func _init() -> void:
	weapon_id = "fus_plasma"
	display_name = "Plasma Burst"
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
	var n: int = cfg.count_base + count_level()
	var dmg: float = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	for i in n:
		var p := Projectile.new()
		p.source_pid = player.peer_id
		p.source_weapon = self
		p.velocity = dir.rotated(deg_to_rad(cfg.spread_deg) * (i - (n - 1) / 2.0)) * cfg.speed
		p.damage = dmg
		p.radius = cfg.radius * fuse_area()
		p.life = cfg.life * fuse_duration()
		p.explode_radius = cfg.explode_radius * fuse_area()  # the bolt blooms a real nova ring, not a pop
		p.explode_damage = dmg * cfg.explode_dmg_ratio
		p.push_strength = cfg.push * fuse_area()
		p.color = Color(1.0, 0.5, 0.9)
		p.position = player.global_position
		player.get_parent().add_child(p)
	Sfx.play("nova", player.global_position)
	cooldown = cfg.cd * fuse_rate()
