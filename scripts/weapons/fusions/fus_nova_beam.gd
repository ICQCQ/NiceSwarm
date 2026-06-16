# --- laser + nova ------------------------------------------------------------
class_name FusNovaBeam
extends WeaponBase

const SPIN := 1.4
const HIT_CD := 0.3
var angle := 0.0
var hit_cd := {}
var nova_cd := 0.0
func _init() -> void:
	weapon_id = "fus_novabeam"
	display_name = "Nova Beam"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		queue_redraw()
		return
	angle = fmod(angle + SPIN / fuse_rate() * delta, TAU)
	queue_redraw()
	var expired := []
	for k in hit_cd:
		hit_cd[k] -= delta
		if hit_cd[k] <= 0.0:
			expired.append(k)
	for k in expired:
		hit_cd.erase(k)
	var beams := 1 + count_level()
	var length := (240.0 + 30.0 * (level - 1)) * fuse_area()
	var dmg := 1.4 * fuse_damage() * (1.0 + 0.4 * (level - 1))
	for e in Main.instance.enemies_in_radius(global_position, length + 64.0):
		if hit_cd.has(e.get_instance_id()):
			continue
		var rel: Vector2 = e.global_position - global_position
		for b in beams:
			var dir := Vector2.from_angle(angle + TAU * float(b) / beams)
			var along := clampf(rel.dot(dir), 0.0, length)
			if (dir * along).distance_to(rel) <= 6.0 + e.radius:
				damage_dealt += dmg
				e.take_hit(dmg, global_position + dir * along, Enemy.DMG_ENERGY, player.peer_id)
				ignite(e, dmg)
				hit_cd[e.get_instance_id()] = HIT_CD * fuse_rate()
				break
	nova_cd -= delta
	if nova_cd <= 0.0:
		var radius := (130.0 + 26.0 * (level - 1)) * fuse_area()  # nova back to good area
		var ndmg := 2.8 * fuse_damage() * (1.0 + 0.4 * (level - 1))
		var any := false
		for e in Main.instance.enemies_in_radius(global_position, radius + 64.0):
			if global_position.distance_to(e.global_position) <= radius + e.radius:
				damage_dealt += ndmg
				e.take_hit(ndmg, global_position, Enemy.DMG_ENERGY, player.peer_id)
				push(e, global_position)
				any = true
		if any:
			var fx := RingFx.new()
			fx.position = global_position
			fx.radius = 25.0
			fx.max_radius = radius
			fx.life = 0.35
			fx.color = Color(1.0, 0.6, 0.7)
			player.get_parent().add_child(fx)
			Sfx.play("nova", global_position)
			nova_cd = 2.6 * fuse_rate()
		else:
			nova_cd = 0.3
func _draw() -> void:
	if player == null or player.downed:
		return
	var beams := 1 + count_level()
	var length := (240.0 + 30.0 * (level - 1)) * fuse_area()
	for b in beams:
		var dir := Vector2.from_angle(angle + TAU * float(b) / beams)
		draw_line(Vector2.ZERO, dir * length, Color(1.0, 0.4, 0.5, 0.25), 9.0)
		draw_line(Vector2.ZERO, dir * length, Color(1.0, 0.6, 0.7), 3.0)
