# --- nova + venom ------------------------------------------------------------
class_name FusToxicNova
extends WeaponBase

var cooldown := 1.6
func _init() -> void:
	weapon_id = "fus_toxicnova"
	display_name = "Toxic Nova"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	var radius := (238.0 + 10.0 * (count_level() - 1)) * fuse_area()
	var dmg := 8.9 * fuse_damage() * (1.0 + GameConfig.FUSION_LEVEL_GROWTH * (level - 1))  # ring = nova @L7 (13.35 eff)
	var any := false
	for e in Main.instance.enemies_in_radius(global_position, radius + 64.0):
		if global_position.distance_to(e.global_position) <= radius + e.radius:
			damage_dealt += dmg
			e.take_hit(dmg, global_position, Enemy.DMG_PHYS, player.peer_id)
			e.apply_burn(dmg * 0.3, 1.5 * fuse_duration(), 1.0, player.peer_id)
			push(e, global_position)
			any = true
	if not any:
		cooldown = 0.25
		return
	var fx := RingFx.new()
	fx.position = global_position
	fx.radius = 25.0
	fx.max_radius = radius
	fx.life = 0.4
	fx.color = Color(0.5, 0.9, 0.4)
	player.get_parent().add_child(fx)
	var pud := VenomPuddle.new()
	pud.source_pid = player.peer_id
	pud.source_weapon = self
	pud.radius = radius * 0.7
	pud.damage = dmg * 0.25
	pud.max_life = 2.5 * fuse_duration()
	pud.life = pud.max_life
	pud.position = global_position
	player.get_parent().add_child(pud)
	Sfx.play("nova", global_position)
	cooldown = 2.6 * fuse_rate()
