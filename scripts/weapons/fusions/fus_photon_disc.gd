# --- glaive + laser: boomerangs that fire a piercing beam on hit --------------
class_name FusPhotonDisc
extends WeaponBase

var cooldown := 0.8
func _init() -> void:
	weapon_id = "fus_photondisc"
	display_name = "Photon Disc"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	var target := player.nearest_enemy(650.0)
	if target == null:
		cooldown = 0.1
		return
	var count := 1 + count_level()
	var base := (target.global_position - player.global_position).normalized()
	var dmg := 2.6 * fuse_damage() * (1.0 + 0.35 * (level - 1))
	for i in count:
		var g := GlaiveProj.new()
		g.source_pid = player.peer_id
		g.source_weapon = self
		g.player = player
		g.velocity = base.rotated(deg_to_rad(20.0) * (i - (count - 1) / 2.0)) * 430.0
		g.damage = dmg
		g.hit_radius = 13.0 * fuse_area()
		g.on_hit = Callable(self, "_on_hit")
		g.position = player.global_position
		player.get_parent().add_child(g)
	Sfx.play("glaive", player.global_position)
	cooldown = 1.1 * fuse_rate()

## Each glaive hit fires a short piercing beam along its travel direction.
func _on_hit(e: Node2D, pos: Vector2) -> void:
	var dir: Vector2 = (e.global_position - player.global_position).normalized()
	var length := 220.0 * fuse_area()
	var dmg := 1.4 * fuse_damage() * (1.0 + 0.35 * (level - 1))
	for en in Main.instance.enemies_in_radius(pos, length + 64.0):
		var rel: Vector2 = en.global_position - pos
		var along := rel.dot(dir)
		if along >= 0.0 and along <= length and (dir * along).distance_to(rel) <= 8.0 + en.radius:
			damage_dealt += dmg
			en.take_hit(dmg, pos, Enemy.DMG_ENERGY, player.peer_id)
			ignite(en, dmg)
	var fx := LightningFx.new()
	fx.points = [pos, pos + dir * length]
	player.get_parent().add_child(fx)
