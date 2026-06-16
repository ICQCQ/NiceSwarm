# --- bolt + lightning --------------------------------------------------------
class_name FusRailgun
extends WeaponBase

var cooldown := 0.7
func _init() -> void:
	weapon_id = "fus_railgun"
	display_name = "Railgun"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	var target := player.nearest_enemy(750.0)
	if target == null:
		cooldown = 0.1
		return
	var dir := (target.global_position - player.global_position).normalized()
	var length := 600.0 * fuse_area()
	var width := 12.0 * fuse_area()
	var dmg := 3.0 * fuse_damage() * (1.0 + 0.4 * (level - 1))
	var origin := player.global_position
	for e in Main.instance.enemies_in_radius(origin, length + 64.0):
		var rel: Vector2 = e.global_position - origin
		var along := rel.dot(dir)
		if along >= 0.0 and along <= length and (dir * along).distance_to(rel) <= width + e.radius:
			damage_dealt += dmg
			e.take_hit(dmg, origin, Enemy.DMG_PHYS, player.peer_id)
			ignite(e, dmg)
	var fx := LightningFx.new()
	fx.points = [origin, origin + dir * length]
	player.get_parent().add_child(fx)
	Sfx.play("lightning", origin)
	cooldown = 1.3 * fuse_rate()
