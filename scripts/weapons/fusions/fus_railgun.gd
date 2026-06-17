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
	var target := player.nearest_enemy(999.0)
	if target == null:
		cooldown = 0.1
		return
	var dir := (target.global_position - player.global_position).normalized()
	var length := 999.0 * fuse_area()            # long line-of-sight rail
	var zap_r := 50.0 * fuse_area()              # one block (~100px) wide zap corridor
	var dmg := 5.0 * fuse_damage() * (1.0 + 0.4 * (level - 1))
	var origin := player.global_position
	var fx := LightningFx.new()
	fx.points = [origin, origin + dir * length]
	player.get_parent().add_child(fx)
	for e in Main.instance.enemies_in_radius(origin, length + zap_r + 64.0):
		var rel: Vector2 = e.global_position - origin
		var along := rel.dot(dir)
		if along < 0.0 or along > length:
			continue
		var beam_pt := origin + dir * along
		if beam_pt.distance_to(e.global_position) > zap_r + e.radius:
			continue
		damage_dealt += dmg
		e.take_hit(dmg, origin, Enemy.DMG_PHYS, player.peer_id)
		ignite(e, dmg)
		var z := LightningFx.new()            # arc from the beam to each zapped foe
		z.points = [beam_pt, e.global_position]
		player.get_parent().add_child(z)
	Sfx.play("lightning", origin)
	cooldown = 0.9 * fuse_rate()
