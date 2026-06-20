# --- flame + laser: a tracking reticle that calls down a scorching beam -------
class_name FusSolarBeam
extends WeaponBase
## Slowly chases the player's aim, then locks and beams sunlight into that spot:
## continuous high damage + burn, ramping the longer an enemy keeps standing in
## it. Cycles between a harmless TRACKING phase (the telegraph / "downtime") and
## a damaging BEAMING phase ("uptime"). Duration shifts the uptime/downtime
## SPLIT of a fixed-length cycle (see `_uptime_ratio`) -- a high-Duration build
## gets a near-permanent beam without the cycle ever stalling out entirely; Haste
## then additionally compresses the resulting downtime (see `_downtime`), so a
## fast build also cycles back to the beam sooner.

var field_pos := Vector2.ZERO
var charging := true
var phase_t := 0.0
var tick := 0.0
var exposure := {}   # enemy instance id -> seconds of unbroken dwell time this beam


func _init() -> void:
	weapon_id = "fus_solarbeam"
	display_name = "Solar Beam"


func _ready() -> void:
	super._ready()
	field_pos = player.global_position
	phase_t = _downtime()  # start tracking, so the first beam is telegraphed, not instant


## Higher Duration both grows uptime AND shrinks downtime by the same amount --
## the cycle period itself never changes -- min/max keep a beam that's always at
## least a brief telegraph and never a literal 100%-uptime laser.
func _uptime_ratio() -> float:
	return clampf(cfg.uptime_ratio_base * fuse_duration(), cfg.uptime_ratio_min, cfg.uptime_ratio_max)
func _uptime() -> float:
	return cfg.cycle * _uptime_ratio()
## Haste compresses downtime on top of Duration's uptime/downtime split -- a
## faster build cycles back to the beam sooner, same as Haste speeding up any
## other cooldown. Floored so heavy Haste can't erase the telegraph outright.
func _downtime() -> float:
	return maxf(cfg.cycle * (1.0 - _uptime_ratio()) * fuse_rate(), cfg.downtime_min)
## Radius steps up every 2 levels (1-2, 3-4, 5-6, 7) rather than smoothly per
## level, so a level-up feels like a real expansion of the field, not a sliver.
func _radius() -> float:
	var steps := (level - 1) / 2
	return (cfg.radius_base + cfg.radius_per_step * steps) * fuse_area()


func _physics_process(delta: float) -> void:
	queue_redraw()
	if player == null or player.downed:
		return
	phase_t -= delta
	if charging:
		_chase(delta)
		if phase_t <= 0.0:
			charging = false
			phase_t = _uptime()
			exposure.clear()
			tick = 0.0
			Sfx.play("nova", field_pos, -8.0)
		return
	tick -= delta
	if tick <= 0.0:
		tick = cfg.tick * fuse_rate()
		_scorch(tick)
	if phase_t <= 0.0:
		charging = true
		phase_t = _downtime()


## Reticle drifts toward the aim target, never snapping -- Haste speeds up the
## chase (same `/ fuse_rate()` pattern as every other Haste-scaled travel speed
## in the codebase, e.g. the orbiting fusions' spin rate).
func _chase(delta: float) -> void:
	var target := _aim_target()
	var to_target := target - field_pos
	var dist := to_target.length()
	if dist > 1.0:
		field_pos += to_target.normalized() * minf(cfg.track_speed / fuse_rate() * delta, dist)


## The local player's actual mouse world position (`Player.aim_point`, free --
## never networked) is the real cursor, clamped to a max leash so the field can't
## roam the whole map; remote puppets never get a synced cursor position (only
## the resulting `facing` unit vector crosses the wire -- see Player._update_aim),
## so their copy of this weapon falls back to a fixed-distance point along it.
func _aim_target() -> Vector2:
	var reach: float = cfg.track_reach * fuse_area()
	if player.is_local:
		var to_mouse := player.aim_point - player.global_position
		if to_mouse.length() > reach:
			to_mouse = to_mouse.normalized() * reach
		return player.global_position + to_mouse
	return player.global_position + player.facing * reach


## One damage tick on everyone currently inside the locked field. `dwell` is
## this tick's elapsed time, added to each hit enemy's running exposure -- so
## damage (and burn) ramps the longer they stay, and resets the instant they
## step out of the field.
func _scorch(dwell: float) -> void:
	var radius := _radius()
	var dmg: float = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	var seen := {}
	var any := false
	for e in Main.instance.enemies_in_radius(field_pos, radius + 64.0):
		if field_pos.distance_to(e.global_position) > radius + e.radius:
			continue
		var id := e.get_instance_id()
		var exposed: float = exposure.get(id, 0.0) + dwell
		exposure[id] = exposed
		seen[id] = true
		var hit: float = dmg * (1.0 + minf(cfg.ramp_per_sec * exposed, cfg.ramp_cap))
		damage_dealt += hit
		e.take_hit(hit, field_pos, Enemy.DMG_FIRE, player.peer_id)
		e.apply_burn(hit * cfg.burn_dps_ratio, cfg.burn_dur * fuse_duration(), 1.0, player.peer_id)
		any = true
	for id in exposure.keys():
		if not seen.has(id):
			exposure.erase(id)  # stepped out -- exposure resets, no partial credit
	if any:
		Sfx.play("laser", field_pos, -8.0)


func _draw() -> void:
	if player == null or player.downed:
		return
	var local := field_pos - global_position
	var radius := _radius()
	if charging:
		var ready_frac := 1.0 - clampf(phase_t / maxf(_downtime(), 0.001), 0.0, 1.0)
		draw_arc(local, radius, 0.0, TAU, 28, Color(1.0, 0.85, 0.3, 0.18 + 0.12 * ready_frac), 2.0)
		draw_arc(local, radius * 0.96, -PI / 2.0, -PI / 2.0 + TAU * ready_frac, 20,
			Color(1.0, 0.95, 0.6, 0.8), 3.0)
	else:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02)
		draw_circle(local, radius, Color(1.0, 0.78, 0.25, 0.16))
		draw_arc(local, radius, 0.0, TAU, 32, Color(1.0, 0.9, 0.5, 0.6 + 0.3 * pulse), 3.0)
		draw_line(local + Vector2(0.0, -600.0), local, Color(1.0, 0.95, 0.7, 0.35), radius * 0.5)
		draw_line(local + Vector2(0.0, -600.0), local, Color(1.0, 1.0, 0.85, 0.5), radius * 0.18)
