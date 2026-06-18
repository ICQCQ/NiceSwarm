# --- orbit + venom -----------------------------------------------------------
class_name FusToxicHalo
extends WeaponBase

const HIT_CD := 0.5
var angle := 0.0
var hit_cd := {}
var trail_cd := 0.0
func _init() -> void:
	weapon_id = "fus_toxhalo"
	display_name = "Toxic Halo"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		queue_redraw()
		return
	angle = fmod(angle + 2.6 / fuse_rate() * delta, TAU)
	queue_redraw()
	var expired := []
	for k in hit_cd:
		hit_cd[k] -= delta
		if hit_cd[k] <= 0.0:
			expired.append(k)
	for k in expired:
		hit_cd.erase(k)
	var n: int = cfg.count_base + count_level()
	var orbit_r: float = cfg.orbit_r * fuse_area()
	var blade_r: float = cfg.blade_r * fuse_area()
	var dmg: float = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	for e in Main.instance.enemies_in_radius(global_position, orbit_r + blade_r + 64.0):
		if hit_cd.has(e.get_instance_id()):
			continue
		for i in n:
			var bp: Vector2 = global_position + Vector2.from_angle(angle + TAU * float(i) / n) * orbit_r
			if bp.distance_to(e.global_position) <= blade_r + e.radius:
				damage_dealt += dmg
				e.take_hit(dmg, bp, Enemy.DMG_PHYS, player.peer_id)
				e.apply_burn(dmg * cfg.poison_dps_ratio, cfg.poison_dur * fuse_duration(), 1.0, player.peer_id)  # poison
				hit_cd[e.get_instance_id()] = HIT_CD * fuse_rate()
				break
	# every blade continuously paints a toxic ring along its orbit path — one puddle per
	# blade each tick (rate kept constant: n drops per 0.16s == the old 1 drop per 0.16/n s)
	trail_cd -= delta
	if trail_cd <= 0.0:
		trail_cd = cfg.trail_cd * fuse_rate()
		for i in n:
			var pud := VenomPuddle.new()
			pud.source_pid = player.peer_id
			pud.source_weapon = self
			pud.radius = (cfg.puddle_radius + cfg.puddle_radius_per_level * (level - 1)) * fuse_area()
			pud.damage = cfg.puddle_dmg * fuse_damage() * (1.0 + cfg.puddle_dmg_growth * (level - 1))
			pud.max_life = cfg.puddle_life * fuse_duration()
			pud.life = pud.max_life
			pud.position = global_position + Vector2.from_angle(angle + TAU * float(i) / n) * orbit_r
			player.get_parent().add_child(pud)
func _draw() -> void:
	if player == null or player.downed:
		return
	var n: int = cfg.count_base + count_level()
	var orbit_r: float = cfg.orbit_r * fuse_area()
	var blade_r: float = cfg.blade_r * fuse_area()
	for i in n:
		var p := Vector2.from_angle(angle + TAU * float(i) / n) * orbit_r
		draw_circle(p, blade_r, Color(0.5, 0.85, 0.4))
		draw_circle(p, blade_r * 0.5, Color(0.7, 1.0, 0.5))
