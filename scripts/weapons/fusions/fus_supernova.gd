# --- flame + nova ------------------------------------------------------------
class_name FusSupernova
extends WeaponBase

var cooldown := 1.8
func _init() -> void:
	weapon_id = "fus_supernova"
	display_name = "Supernova"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	var radius := (270.0 + 10.0 * (count_level() - 1)) * fuse_area()
	var dmg := 3.5 * fuse_damage() * (1.0 + 0.5 * (level - 1))
	var hit_any := false
	for e in Main.instance.enemies_in_radius(global_position, radius + 64.0):
		if global_position.distance_to(e.global_position) <= radius + e.radius:
			damage_dealt += dmg
			e.take_hit(dmg, global_position, Enemy.DMG_PHYS, player.peer_id)
			ignite(e, dmg)
			push(e, global_position)
			hit_any = true
	if not hit_any:
		cooldown = 0.25
		return
	var fx := RingFx.new()
	fx.position = global_position
	fx.radius = 30.0
	fx.max_radius = radius
	fx.life = 0.4
	fx.color = Color(1.0, 0.5, 0.2)
	player.get_parent().add_child(fx)
	var pud := VenomPuddle.new()
	pud.source_pid = player.peer_id
	pud.source_weapon = self
	pud.radius = radius * 0.7
	pud.damage = dmg * 0.2
	pud.max_life = 2.0 * fuse_duration()
	pud.life = pud.max_life
	pud.fiery = true
	pud.burn_dps = dmg * 0.2
	pud.burn_dur = 1.0 * fuse_duration()
	pud.position = global_position
	player.get_parent().add_child(pud)
	Sfx.play("nova", global_position)
	cooldown = 2.8 * fuse_rate()
