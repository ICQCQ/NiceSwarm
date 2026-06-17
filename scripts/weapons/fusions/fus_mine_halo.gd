# --- mines + orbit: orbiting blades that fling mines -------------------------
class_name FusMineHalo
extends WeaponBase

const ORBIT_R := 80.0
const BLADE_R := 11.0
const HIT_CD := 0.5
var angle := 0.0
var hit_cd := {}
var drop_cd := 0.0
func _init() -> void:
	weapon_id = "fus_minehalo"
	display_name = "Mine Halo"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		queue_redraw()
		return
	angle = fmod(angle + 3.0 / fuse_rate() * delta, TAU)
	queue_redraw()
	var expired := []
	for k in hit_cd:
		hit_cd[k] -= delta
		if hit_cd[k] <= 0.0:
			expired.append(k)
	for k in expired:
		hit_cd.erase(k)
	var n := 2 + count_level()
	var orbit_r := ORBIT_R * fuse_area()
	var blade_r := BLADE_R * fuse_area()
	var dmg := 2.0 * fuse_damage() * (1.0 + 0.4 * (level - 1))
	for e in Main.instance.enemies_in_radius(global_position, orbit_r + blade_r + 64.0):
		if hit_cd.has(e.get_instance_id()):
			continue
		for i in n:
			var bp: Vector2 = global_position + Vector2.from_angle(angle + TAU * float(i) / n) * orbit_r
			if bp.distance_to(e.global_position) <= blade_r + e.radius:
				damage_dealt += dmg
				e.take_hit(dmg, bp, Enemy.DMG_PHYS, player.peer_id)
				hit_cd[e.get_instance_id()] = HIT_CD * fuse_rate()
				break
	drop_cd -= delta
	if drop_cd <= 0.0 and get_tree().get_nodes_in_group("mines").size() < 4 + count_level():
		var bp := global_position + Vector2.from_angle(angle) * orbit_r * 1.4
		var m := MineNode.new()
		m.source_pid = player.peer_id
		m.source_weapon = self
		m.damage = 5.0 * fuse_damage() * (1.0 + 0.4 * (level - 1))
		m.blast_radius = 90.0 * fuse_area()
		m.trigger_radius = 50.0 * fuse_area()
		m.life = 10.0 * fuse_duration()
		m.position = bp
		player.get_parent().add_child(m)
		Sfx.play("mine", bp)
		drop_cd = 1.3 * fuse_rate()
func _draw() -> void:
	if player == null or player.downed:
		return
	var n := 2 + count_level()
	var orbit_r := ORBIT_R * fuse_area()
	var blade_r := BLADE_R * fuse_area()
	for i in n:
		var p := Vector2.from_angle(angle + TAU * float(i) / n) * orbit_r
		draw_circle(p, blade_r, Color(0.8, 0.7, 0.5))
		draw_circle(p, blade_r * 0.45, Color(1.0, 0.3, 0.2))
