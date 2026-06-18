# --- glaive + orbit: orbiting blades that launch a returning glaive ----------
class_name FusBladeTempest
extends WeaponBase

const HIT_CD := 0.5
var angle := 0.0
var hit_cd := {}
var launch_cd := 0.0
var detached := 0
func _init() -> void:
	weapon_id = "fus_bladetempest"
	display_name = "Blade Tempest"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		queue_redraw()
		return
	angle = fmod(angle + cfg.spin / fuse_rate() * delta, TAU)
	queue_redraw()
	var expired := []
	for k in hit_cd:
		hit_cd[k] -= delta
		if hit_cd[k] <= 0.0:
			expired.append(k)
	for k in expired:
		hit_cd.erase(k)
	var total: int = cfg.count_base + count_level()
	# blades that have detached to strike leave a gap in the ring until they return
	var n := maxi(total - detached, 1)
	var orbit_r: float = cfg.orbit_radius * fuse_area()
	var blade_r: float = cfg.blade_radius * fuse_area()
	var dmg: float = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
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
	launch_cd -= delta
	if launch_cd <= 0.0 and detached < total - 1:
		var target := player.nearest_enemy(cfg.launch_range)
		if target == null:
			launch_cd = 0.2
			return
		detached += 1
		var g := GlaiveProj.new()
		g.source_pid = player.peer_id
		g.source_weapon = self
		g.player = player
		g.velocity = (target.global_position - player.global_position).normalized() * cfg.launch_speed
		g.damage = cfg.launch_dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
		g.hit_radius = cfg.launch_hit_radius * fuse_area()
		g.position = global_position + Vector2.from_angle(angle) * orbit_r
		g.tree_exited.connect(func(): detached = maxi(detached - 1, 0))
		player.get_parent().add_child(g)
		Sfx.play("glaive", player.global_position)
		launch_cd = cfg.launch_cd * fuse_rate()
func _draw() -> void:
	if player == null or player.downed:
		return
	var total: int = cfg.count_base + count_level()
	var n := maxi(total - detached, 1)
	var orbit_r: float = cfg.orbit_radius * fuse_area()
	var blade_r: float = cfg.blade_radius * fuse_area()
	for i in n:
		var p := Vector2.from_angle(angle + TAU * float(i) / n) * orbit_r
		draw_circle(p, blade_r, Color(0.8, 0.8, 0.85))
		draw_circle(p, blade_r * 0.5, Color(0.6, 0.95, 0.85))
