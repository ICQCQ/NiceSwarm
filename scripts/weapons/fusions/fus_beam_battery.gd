# --- laser + missiles: rotating beams paint targets for a missile volley ----
class_name FusBeamBattery
extends WeaponBase

const TAG_DUR := 2.0
var angle := 0.0
var tagged := {}  # enemy instance id -> remaining lock time (painted by a beam)
var missile_cd := 0.0
func _init() -> void:
	weapon_id = "fus_beambattery"
	display_name = "Beam Battery"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		queue_redraw()
		return
	angle = fmod(angle + 1.6 / fuse_rate() * delta, TAU)
	queue_redraw()
	var texpired := []
	for k in tagged:
		tagged[k] -= delta
		if tagged[k] <= 0.0:
			texpired.append(k)
	for k in texpired:
		tagged.erase(k)
	var beams := 1 + count_level()
	var length := (244.0 + 8.0 * (count_level() - 1)) * fuse_area()
	# beams deal no damage of their own -- they just paint targets
	for e in Main.instance.enemies_in_radius(global_position, length + 64.0):
		var rel: Vector2 = e.global_position - global_position
		for b in beams:
			var dir := Vector2.from_angle(angle + TAU * float(b) / beams)
			var along := clampf(rel.dot(dir), 0.0, length)
			if (dir * along).distance_to(rel) <= 9.0 + e.radius:
				tagged[e.get_instance_id()] = TAG_DUR * fuse_duration()
				break
	# on cooldown, fire a homing missile at every currently-painted enemy
	missile_cd -= delta
	if missile_cd <= 0.0:
		var locks: Array = []
		for id in tagged:
			var e := instance_from_id(id) as Node2D
			if is_instance_valid(e):
				locks.append(e)
		if locks.is_empty():
			missile_cd = 0.2
			return
		var dmg := 6.1 * fuse_damage() * (1.0 + GameConfig.FUSION_LEVEL_GROWTH * (level - 1))
		for lock in locks:
			var m := MissileProj.new()
			m.source_pid = player.peer_id
			m.source_weapon = self
			m.target = lock
			m.damage = dmg
			m.splash = (65.0 + 8.0 * (level - 1)) * fuse_area()
			m.life = 4.0 * fuse_duration()
			m.velocity = (lock.global_position - global_position).normalized() * 280.0
			m.fire_dps = 0.7 * fuse_damage() * (1.0 + 0.35 * (level - 1))
			m.fire_radius = (55.0 + 8.0 * (level - 1)) * fuse_area()
			m.fire_dur = 1.6 * fuse_duration()
			m.position = global_position
			player.get_parent().add_child(m)
		Sfx.play("missile", global_position)
		tagged.clear()
		missile_cd = 1.8 * fuse_rate()
func _draw() -> void:
	if player == null or player.downed:
		return
	var beams := 1 + count_level()
	var length := (244.0 + 8.0 * (count_level() - 1)) * fuse_area()
	for b in beams:
		var dir := Vector2.from_angle(angle + TAU * float(b) / beams)
		draw_line(Vector2.ZERO, dir * length, Color(1.0, 0.7, 0.3, 0.22), 12.0)
		draw_line(Vector2.ZERO, dir * length, Color(1.0, 0.9, 0.6), 2.5)
		draw_circle(dir * length, 7.0 * fuse_area(), Color(1.0, 0.8, 0.4))
