# --- lightning + orbit -------------------------------------------------------
class_name FusTeslaHalo
extends WeaponBase

const ORBIT_R := 80.0
const BLADE_R := 11.0
const HIT_CD := 0.5
var angle := 0.0
var hit_cd := {}
func _init() -> void:
	weapon_id = "fus_teslahalo"
	display_name = "Tesla Halo"
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
				e.take_hit(dmg, bp, Enemy.DMG_ENERGY, player.peer_id)
				ignite(e, dmg)
				hit_cd[e.get_instance_id()] = HIT_CD * fuse_rate()
				_zap(e, dmg)
				break
func _zap(src: Node2D, dmg: float) -> void:
	var best: Node2D = null
	var bd := 170.0 * 170.0
	for e in Main.instance.enemies_in_radius(src.global_position, 170.0 + 64.0):
		if e == src:
			continue
		var d: float = src.global_position.distance_squared_to(e.global_position)
		if d < bd:
			bd = d
			best = e
	if best == null:
		return
	damage_dealt += dmg * 0.7
	best.take_hit(dmg * 0.7, src.global_position, Enemy.DMG_ENERGY, player.peer_id)
	var fx := LightningFx.new()
	fx.points = [src.global_position, best.global_position]
	player.get_parent().add_child(fx)
func _draw() -> void:
	if player == null or player.downed:
		return
	var n := 2 + count_level()
	var orbit_r := ORBIT_R * fuse_area()
	var blade_r := BLADE_R * fuse_area()
	for i in n:
		var p := Vector2.from_angle(angle + TAU * float(i) / n) * orbit_r
		draw_circle(p, blade_r, Color(0.6, 0.8, 1.0))
		draw_circle(p, blade_r * 0.5, Color(0.9, 0.95, 1.0))
