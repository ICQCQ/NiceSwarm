# --- frost + venom: a pool that chills and poisons ---------------------------
class_name FusFrostbite
extends WeaponBase

var cooldown := 1.5
func _init() -> void:
	weapon_id = "fus_frostbite"
	display_name = "Frostbite"
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
	var dmg: float = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	var pud := VenomPuddle.new()
	pud.source_pid = player.peer_id
	pud.source_weapon = self
	pud.radius = (cfg.radius + cfg.radius_per_count * (count_level() - 1)) * fuse_area()
	pud.damage = dmg
	pud.max_life = cfg.life * fuse_duration()
	pud.life = pud.max_life
	pud.icy = true
	pud.freeze_slow = cfg.freeze_slow
	pud.freeze_dur = dmg * cfg.freeze_dur_ratio * fuse_duration()
	pud.position = target.global_position
	player.get_parent().add_child(pud)
	Sfx.play("frost", target.global_position)
	cooldown = cfg.cd * fuse_rate()
