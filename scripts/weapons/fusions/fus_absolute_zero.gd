# --- frost + nova: a freezing nova -------------------------------------------
class_name FusAbsoluteZero
extends WeaponBase

var cooldown := 1.6
func _init() -> void:
	weapon_id = "fus_abszero"
	display_name = "Absolute Zero"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	var radius := (270.0 + 10.0 * (count_level() - 1)) * fuse_area()  # bigger freezing nova
	var dmg := 8.9 * fuse_damage() * (1.0 + GameConfig.FUSION_LEVEL_GROWTH * (level - 1))  # ring = nova @L7 (13.35 eff)
	var any := false
	for e in Main.instance.enemies_in_radius(global_position, radius + 64.0):
		if global_position.distance_to(e.global_position) <= radius + e.radius:
			damage_dealt += dmg
			e.take_hit(dmg, global_position, Enemy.DMG_ICE, player.peer_id)
			e.apply_slow(0.5, 2.0 * fuse_duration())
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
	fx.color = Color(0.6, 0.9, 1.0)
	player.get_parent().add_child(fx)
	Sfx.play("frost", global_position)
	cooldown = 2.4 * fuse_rate()
