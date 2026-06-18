# --- flame + gravity: a vortex with a burning pool at its core ---------------
class_name FusCinderVortex
extends WeaponBase

var cooldown := 2.8
func _init() -> void:
	weapon_id = "fus_cindervortex"
	display_name = "Cinder Vortex"
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
	var r: float = (cfg.radius_base + cfg.radius_per_count * (count_level() - 1)) * fuse_area()
	var life: float = cfg.life * fuse_duration()
	var dmg: float = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	var w := GravityWell.new()
	w.source_pid = player.peer_id
	w.source_weapon = self
	w.radius = r
	w.damage = cfg.well_dmg_ratio * dmg
	w.pull = cfg.pull
	w.life = life
	w.position = target.global_position
	player.get_parent().add_child(w)
	var pud := VenomPuddle.new()
	pud.source_pid = player.peer_id
	pud.source_weapon = self
	pud.radius = r * cfg.pool_radius_ratio
	pud.damage = cfg.pool_dmg_ratio * dmg
	pud.max_life = life
	pud.life = life
	pud.fiery = true
	pud.burn_dps = cfg.burn_dps_ratio * dmg
	pud.burn_dur = cfg.burn_dur * fuse_duration()
	pud.position = target.global_position
	player.get_parent().add_child(pud)
	Sfx.play("flame", target.global_position)
	cooldown = cfg.cd * fuse_rate()
