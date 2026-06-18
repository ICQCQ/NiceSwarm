# --- glaive + orbit: orbiting balls that periodically spurt outward like a --
# comet's tail, then slowly drift back to their normal orbit -----------------
class_name FusHaloComet
extends WeaponBase

const HIT_CD := 0.5
const OUT_TIME := 0.22    # quick snap outward
const RETURN_TIME := 1.4  # slow drift back to normal orbit
var angle := 0.0
var hit_cd := {}
var spurt_cd := 0.0
var spurt_t := RETURN_TIME + OUT_TIME  # starts already settled at the normal orbit
func _init() -> void:
	weapon_id = "fus_halocomet"
	display_name = "Halo Comet"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		queue_redraw()
		return
	angle = fmod(angle + cfg.spin / fuse_rate() * delta, TAU)
	var expired := []
	for k in hit_cd:
		hit_cd[k] -= delta
		if hit_cd[k] <= 0.0:
			expired.append(k)
	for k in expired:
		hit_cd.erase(k)
	spurt_cd -= delta
	spurt_t += delta
	if spurt_cd <= 0.0:
		spurt_cd = cfg.spurt_cd * fuse_rate()  # Haste: shortens the spurt-out period
		spurt_t = 0.0
	var spurt_frac := _spurt_frac()
	var n: int = cfg.count_base + count_level()
	var orbit_r: float = cfg.orbit_radius * fuse_area() + cfg.spurt_range * fuse_duration() * spurt_frac  # Duration: max spurt range
	var blade_r: float = cfg.blade_radius * fuse_area() * (1.0 + cfg.spurt_size_bonus * spurt_frac)  # Area: ball size; grows further mid-spurt
	var dmg: float = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1)) * (1.0 + cfg.spurt_dmg_bonus * spurt_frac)
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
	queue_redraw()
## 0 at rest, 1 at the peak of the spurt -- ramps out fast over OUT_TIME, then
## eases back down to 0 over the much longer RETURN_TIME.
func _spurt_frac() -> float:
	if spurt_t <= OUT_TIME:
		return spurt_t / OUT_TIME
	if spurt_t <= OUT_TIME + RETURN_TIME:
		return 1.0 - (spurt_t - OUT_TIME) / RETURN_TIME
	return 0.0
func _draw() -> void:
	if player == null or player.downed:
		return
	var spurt_frac := _spurt_frac()
	var n: int = cfg.count_base + count_level()
	var orbit_r: float = cfg.orbit_radius * fuse_area() + cfg.spurt_range * fuse_duration() * spurt_frac
	var blade_r: float = cfg.blade_radius * fuse_area() * (1.0 + cfg.spurt_size_bonus * spurt_frac)
	for i in n:
		var p := Vector2.from_angle(angle + TAU * float(i) / n) * orbit_r
		draw_circle(p, blade_r, Color(0.8, 0.8, 0.85))
		draw_circle(p, blade_r * 0.5, Color(0.6, 0.95, 0.85))
