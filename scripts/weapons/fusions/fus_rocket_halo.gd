# --- missiles + orbit: orbiting blades backed by homing rocket fire ----------
class_name FusRocketHalo
extends WeaponBase

const ORBIT_R := 78.0
const BLADE_R := 11.0
const HIT_CD := 0.5
const TAG_DUR := 2.5
var angle := 0.0
var hit_cd := {}
var tagged := {}  # enemy instance id -> remaining lock time
var missile_cd := 0.0
func _init() -> void:
	weapon_id = "fus_rockethalo"
	display_name = "Rocket Halo"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		queue_redraw()
		return
	angle = fmod(angle + 2.8 / fuse_rate() * delta, TAU)
	queue_redraw()
	var expired := []
	for k in hit_cd:
		hit_cd[k] -= delta
		if hit_cd[k] <= 0.0:
			expired.append(k)
	for k in expired:
		hit_cd.erase(k)
	var texpired := []
	for k in tagged:
		tagged[k] -= delta
		if tagged[k] <= 0.0:
			texpired.append(k)
	for k in texpired:
		tagged.erase(k)
	var n := 2 + count_level()
	var orbit_r := ORBIT_R * fuse_area()
	var blade_r := BLADE_R * fuse_area()
	var dmg := 5.0 * fuse_damage() * (1.0 + GameConfig.FUSION_LEVEL_GROWTH * (level - 1))
	# blades that strike an enemy paint a lock-on target for the missiles
	for e in Main.instance.enemies_in_radius(global_position, orbit_r + blade_r + 64.0):
		if hit_cd.has(e.get_instance_id()):
			continue
		for i in n:
			var bp: Vector2 = global_position + Vector2.from_angle(angle + TAU * float(i) / n) * orbit_r
			if bp.distance_to(e.global_position) <= blade_r + e.radius:
				damage_dealt += dmg
				e.take_hit(dmg, bp, Enemy.DMG_PHYS, player.peer_id)
				hit_cd[e.get_instance_id()] = HIT_CD * fuse_rate()
				tagged[e.get_instance_id()] = TAG_DUR * fuse_duration()
				break
	missile_cd -= delta
	if missile_cd <= 0.0:
		var lock: Node2D = null
		for e in Main.instance.all_enemies():
			if tagged.has(e.get_instance_id()):
				lock = e
				break
		if lock == null:
			missile_cd = 0.2
			return
		var m := MissileProj.new()
		m.source_pid = player.peer_id
		m.source_weapon = self
		m.target = lock
		m.damage = 6.1 * fuse_damage() * (1.0 + GameConfig.FUSION_LEVEL_GROWTH * (level - 1))
		m.splash = (75.0 + 10.0 * (level - 1)) * fuse_area()
		m.life = 4.0 * fuse_duration()
		m.velocity = (lock.global_position - global_position).normalized() * 280.0
		m.position = global_position
		player.get_parent().add_child(m)
		Sfx.play("missile", global_position)
		missile_cd = 1.6 * fuse_rate()
func _draw() -> void:
	if player == null or player.downed:
		return
	var n := 2 + count_level()
	var orbit_r := ORBIT_R * fuse_area()
	var blade_r := BLADE_R * fuse_area()
	for i in n:
		var p := Vector2.from_angle(angle + TAU * float(i) / n) * orbit_r
		draw_circle(p, blade_r, Color(0.85, 0.6, 0.3))
		draw_circle(p, blade_r * 0.5, Color(1.0, 0.85, 0.5))
