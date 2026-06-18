# --- gravity + venom ---------------------------------------------------------
class_name FusBlackBog
extends WeaponBase

var cooldown := 2.6
func _init() -> void:
	weapon_id = "fus_blackbog"
	display_name = "Black Bog"
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
	w.damage = cfg.well_dmg_ratio * dmg  # +20%: single-well fusion, 75%-of-combined floor
	w.pull = cfg.pull
	w.life = life
	w.position = target.global_position
	player.get_parent().add_child(w)
	var pud := VenomPuddle.new()
	pud.source_pid = player.peer_id
	pud.source_weapon = self
	pud.radius = r * cfg.pool_radius_ratio
	pud.damage = cfg.pool_dmg_ratio * dmg  # +20%: single-well fusion, 75%-of-combined floor
	pud.max_life = life
	pud.life = life
	pud.position = target.global_position
	player.get_parent().add_child(pud)
	Sfx.play("gravity", target.global_position)
	cooldown = cfg.cd * fuse_rate()
