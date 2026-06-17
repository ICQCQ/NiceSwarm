# --- laser + venom: rotating beams that corrode and seed toxic pools ---------
class_name FusAcidRay
extends WeaponBase

const HIT_CD := 0.4
var angle := 0.0
var hit_cd := {}
var pool_cd := 0.0
func _init() -> void:
	weapon_id = "fus_acidray"
	display_name = "Acid Ray"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		queue_redraw()
		return
	angle = fmod(angle + 2.4 / fuse_rate() * delta, TAU)
	queue_redraw()
	var expired := []
	for k in hit_cd:
		hit_cd[k] -= delta
		if hit_cd[k] <= 0.0:
			expired.append(k)
	for k in expired:
		hit_cd.erase(k)
	var beams := 1 + count_level()
	var length := (244.0 + 8.0 * (count_level() - 1)) * fuse_area()
	var dmg := 3.0 * fuse_damage() * (1.0 + GameConfig.FUSION_LEVEL_GROWTH * (level - 1))
	for e in Main.instance.enemies_in_radius(global_position, length + 64.0):
		if hit_cd.has(e.get_instance_id()):
			continue
		var rel: Vector2 = e.global_position - global_position
		for b in beams:
			var dir := Vector2.from_angle(angle + TAU * float(b) / beams)
			var along := clampf(rel.dot(dir), 0.0, length)
			if (dir * along).distance_to(rel) <= 9.0 + e.radius:
				damage_dealt += dmg
				e.take_hit(dmg, global_position + dir * along, Enemy.DMG_ENERGY, player.peer_id)
				e.apply_burn(dmg * 0.5, 1.5 * fuse_duration(), 1.0, player.peer_id)
				hit_cd[e.get_instance_id()] = HIT_CD * fuse_rate()
				break
	pool_cd -= delta
	if pool_cd <= 0.0:
		var dir := Vector2.from_angle(angle)
		var pud := VenomPuddle.new()
		pud.source_pid = player.peer_id
		pud.source_weapon = self
		pud.radius = (45.0 + 6.0 * (level - 1)) * fuse_area()
		pud.damage = 0.7 * fuse_damage() * (1.0 + 0.4 * (level - 1))
		pud.max_life = 2.0 * fuse_duration()
		pud.life = pud.max_life
		pud.position = global_position + dir * length
		player.get_parent().add_child(pud)
		Sfx.play("venom", global_position)
		pool_cd = 2.5 * fuse_rate()
func _draw() -> void:
	if player == null or player.downed:
		return
	var beams := 1 + count_level()
	var length := (244.0 + 8.0 * (count_level() - 1)) * fuse_area()
	for b in beams:
		var dir := Vector2.from_angle(angle + TAU * float(b) / beams)
		draw_line(Vector2.ZERO, dir * length, Color(0.5, 0.9, 0.3, 0.22), 12.0)
		draw_line(Vector2.ZERO, dir * length, Color(0.75, 1.0, 0.5), 2.5)
		draw_circle(dir * length, 7.0 * fuse_area(), Color(0.6, 1.0, 0.4))
