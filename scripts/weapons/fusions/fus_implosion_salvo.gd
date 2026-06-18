# --- gravity + missiles: a vortex that launches a homing missile salvo -------
class_name FusImplosionSalvo
extends WeaponBase

var cooldown := 3.2
func _init() -> void:
	weapon_id = "fus_implosionsalvo"
	display_name = "Implosion Salvo"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	var target := player.nearest_enemy(cfg.range)
	if target == null:
		cooldown = 0.2
		return
	var r: float = (cfg.well_radius + cfg.well_radius_per_level * (level - 1)) * fuse_area()
	var w := GravityWell.new()
	w.source_pid = player.peer_id
	w.source_weapon = self
	w.radius = r
	w.damage = cfg.well_dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	w.pull = cfg.well_pull
	w.life = cfg.well_life * fuse_duration()
	w.position = target.global_position
	player.get_parent().add_child(w)
	var dmg: float = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	var count: int = cfg.count_base + count_level()
	for i in count:
		var m := MissileProj.new()
		m.source_pid = player.peer_id
		m.source_weapon = self
		m.damage = dmg
		m.splash = (cfg.splash + cfg.splash_per_level * (level - 1)) * fuse_area()
		m.life = cfg.life * fuse_duration()
		m.velocity = Vector2.from_angle(TAU * float(i) / count) * cfg.speed
		m.position = player.global_position
		player.get_parent().add_child(m)
	Sfx.play("missile", player.global_position)
	cooldown = cfg.cd * fuse_rate()
