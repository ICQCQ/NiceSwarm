# --- nova + orbit ------------------------------------------------------------
class_name FusPulsar
extends WeaponBase

const HIT_CD := 0.45
const PULSE_CD := 1.6
var angle := 0.0
var hit_cd := {}
var pulse_timers: Array = []
func _init() -> void:
	weapon_id = "fus_pulsar"
	display_name = "Pulsar"
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
	var n: int = cfg.count_base + count_level()
	while pulse_timers.size() < n:
		pulse_timers.append(randf() * PULSE_CD)
	while pulse_timers.size() > n:
		pulse_timers.pop_back()
	var orbit_r: float = cfg.orbit_r * fuse_area()
	var blade_r: float = cfg.blade_r * fuse_area()
	var dmg: float = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	var pulse_radius: float = (cfg.pulse_radius + cfg.pulse_radius_per_level * (level - 1)) * fuse_area()  # real nova area, not a mini bang
	var pulse_dmg: float = cfg.pulse_dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	for i in n:
		var bp: Vector2 = global_position + Vector2.from_angle(angle + TAU * float(i) / n) * orbit_r
		# contact damage from the spinning blade itself
		for e in Main.instance.enemies_in_radius(bp, blade_r + 64.0):
			if not hit_cd.has(e.get_instance_id()) and bp.distance_to(e.global_position) <= blade_r + e.radius:
				damage_dealt += dmg
				e.take_hit(dmg, bp, Enemy.DMG_PHYS, player.peer_id)
				hit_cd[e.get_instance_id()] = HIT_CD * fuse_rate()
		# each blade "breathes": independently pulses a small nova at its own position
		pulse_timers[i] -= delta
		if pulse_timers[i] <= 0.0:
			pulse_timers[i] = PULSE_CD * fuse_rate()
			var any := false
			for e in Main.instance.enemies_in_radius(bp, pulse_radius + 64.0):
				if bp.distance_to(e.global_position) <= pulse_radius + e.radius:
					damage_dealt += pulse_dmg
					e.take_hit(pulse_dmg, bp, Enemy.DMG_ENERGY, player.peer_id)
					ignite(e, pulse_dmg)
					push(e, bp)
					any = true
			if any:
				var fx := RingFx.new()
				fx.position = bp
				fx.radius = blade_r
				fx.max_radius = pulse_radius
				fx.life = 0.3
				fx.color = Color(0.7, 0.6, 1.0)
				player.get_parent().add_child(fx)
				Sfx.play("nova", bp, -6.0)
func _draw() -> void:
	if player == null or player.downed:
		return
	var n: int = cfg.count_base + count_level()
	var orbit_r: float = cfg.orbit_r * fuse_area()
	var blade_r: float = cfg.blade_r * fuse_area()
	for i in n:
		var p := Vector2.from_angle(angle + TAU * float(i) / n) * orbit_r
		var glow := 1.0
		if i < pulse_timers.size():
			glow += 0.8 * clampf(1.0 - pulse_timers[i] / PULSE_CD, 0.0, 1.0)
		draw_circle(p, blade_r * glow, Color(0.7, 0.7, 1.0, 0.55))
		draw_circle(p, blade_r * 0.5, Color(0.4, 0.4, 0.8))
