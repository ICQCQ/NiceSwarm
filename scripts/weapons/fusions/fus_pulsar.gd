# --- nova + orbit: balls orbit you, then periodically swarm a random foe — ---
# spreading into a ring around it before every ball rushes the center and -----
# detonates; they reappear back in orbit afterward to wait out the cooldown ---
class_name FusPulsar
extends WeaponBase

const SPIN_SPEED := 2.2
const APPROACH_TIME := 0.3   # quick fan-out to the ring around the target
const HOLD_TIME := 0.25      # brief stop on the ring before the dive
const RUSH_TIME := 0.18      # fast, deadly final dive
const HIT_CD := 0.5
const ORBIT_HIT_CD := 0.45   # per-enemy re-hit while idle-spinning (matches base Orbit Blades)

enum State { ORBIT, APPROACH, HOLD, RUSH }

var angle := 0.0
var state: int = State.ORBIT
var period_timer := 0.0
var phase_timer := 0.0
var target: Node = null
var target_pos := Vector2.ZERO  # last known target position; frozen if the target dies mid-attack
var ball_pos: Array = []
var ball_start: Array = []
var ring_angle: Array = []      # per-ball angle around the target, fixed for the whole attack
var hit_cd := {}
var orbit_hit_cd := {}
func _init() -> void:
	weapon_id = "fus_pulsar"
	display_name = "Pulsar"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		queue_redraw()
		return
	angle = fmod(angle + SPIN_SPEED / fuse_rate() * delta, TAU)
	_decay_cd(hit_cd, delta)
	_decay_cd(orbit_hit_cd, delta)
	var orbit_r: float = cfg.orbit_r * fuse_area()
	if state == State.ORBIT:
		var n: int = cfg.count_base + count_level()
		while ball_pos.size() < n:
			ball_pos.append(global_position)
		while ball_pos.size() > n:
			ball_pos.pop_back()
		for i in n:
			ball_pos[i] = global_position + Vector2.from_angle(angle + TAU * float(i) / n) * orbit_r
		var ball_r: float = cfg.ball_r * fuse_area()
		var orbit_dmg: float = cfg.orbit_dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
		for e in Main.instance.enemies_in_radius(global_position, orbit_r + ball_r + 64.0):
			if orbit_hit_cd.has(e.get_instance_id()):
				continue
			for p in ball_pos:
				if p.distance_to(e.global_position) <= ball_r + e.radius:
					damage_dealt += orbit_dmg
					e.take_hit(orbit_dmg, p, Enemy.DMG_ENERGY, player.peer_id)
					orbit_hit_cd[e.get_instance_id()] = ORBIT_HIT_CD * fuse_rate()
					break
		period_timer -= delta
		if period_timer <= 0.0:
			_try_start_attack(n)
	elif state == State.APPROACH:
		phase_timer += delta
		var frac: float = clampf(phase_timer / APPROACH_TIME, 0.0, 1.0)
		if is_instance_valid(target):
			target_pos = target.global_position
		var b_range: float = cfg.b_range * fuse_duration()  # Duration: ring distance from the target
		var t := frac * frac * (3.0 - 2.0 * frac)
		for i in ball_pos.size():
			var around: Vector2 = target_pos + Vector2.from_angle(ring_angle[i]) * b_range
			ball_pos[i] = ball_start[i].lerp(around, t)
		if frac >= 1.0:
			state = State.HOLD
			phase_timer = 0.0
	elif state == State.HOLD:
		# target_pos is locked once the ring finishes forming -- the strike point
		# is fixed on the ground from here on, even if the target moves away.
		phase_timer += delta
		var b_range: float = cfg.b_range * fuse_duration()
		for i in ball_pos.size():
			ball_pos[i] = target_pos + Vector2.from_angle(ring_angle[i]) * b_range
		if phase_timer >= HOLD_TIME:
			state = State.RUSH
			phase_timer = 0.0
			ball_start = ball_pos.duplicate()
	elif state == State.RUSH:
		phase_timer += delta
		var frac: float = clampf(phase_timer / RUSH_TIME, 0.0, 1.0)
		var ball_r: float = cfg.ball_r * fuse_area()
		# Duration: the dive itself hits harder, on top of the explosion at the end
		var rush_dmg: float = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1)) * fuse_duration()
		for i in ball_pos.size():
			ball_pos[i] = ball_start[i].lerp(target_pos, frac)
			for e in Main.instance.enemies_in_radius(ball_pos[i], ball_r + 48.0):
				if hit_cd.has(e.get_instance_id()):
					continue
				if ball_pos[i].distance_to(e.global_position) <= ball_r + e.radius:
					damage_dealt += rush_dmg
					e.take_hit(rush_dmg, ball_pos[i], Enemy.DMG_ENERGY, player.peer_id)
					hit_cd[e.get_instance_id()] = HIT_CD * fuse_rate()
		if frac >= 1.0:
			_explode(target_pos)
			state = State.ORBIT
			period_timer = cfg.period * fuse_rate()  # Haste: shortens the wait between attacks
			target = null
	queue_redraw()
func _decay_cd(d: Dictionary, delta: float) -> void:
	var expired := []
	for k in d:
		d[k] -= delta
		if d[k] <= 0.0:
			expired.append(k)
	for k in expired:
		d.erase(k)
func _try_start_attack(n: int) -> void:
	var seek_range: float = cfg.seek_range * fuse_area()  # Area: how far it can spot a target
	var candidates := Main.instance.enemies_in_radius(global_position, seek_range)
	if candidates.is_empty():
		period_timer = 0.25  # nothing nearby yet -- retry soon instead of burning the full wait
		return
	target = candidates[randi() % candidates.size()]
	target_pos = target.global_position
	ball_start = ball_pos.duplicate()
	ring_angle.resize(n)
	for i in n:
		ring_angle[i] = angle + TAU * float(i) / n
	state = State.APPROACH
	phase_timer = 0.0
	Sfx.play("orbit", target_pos, -2.0)
## Every ball that completed the dive detonates at the target's last position --
## more balls (from Level/fusion count) stack into bigger total damage.
func _explode(pos: Vector2) -> void:
	var explode_radius: float = cfg.explode_radius * fuse_area()  # Area: blast size
	# Duration: the payoff hit, scaled hard so a long-leashed swarm pays off
	var explode_dmg: float = cfg.explode_dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1)) * fuse_duration()
	for e in Main.instance.enemies_in_radius(pos, explode_radius + 64.0):
		if pos.distance_to(e.global_position) <= explode_radius + e.radius:
			for i in ball_pos.size():
				damage_dealt += explode_dmg
				e.take_hit(explode_dmg, pos, Enemy.DMG_ENERGY, player.peer_id)
			push(e, pos, 90.0)
	# Always show the payoff burst -- by the time the dive lands the rush/orbit
	# damage has often already cleared whatever was there, but the detonation
	# is the climax of the whole attack cycle and should read even on a miss.
	_spawn_burst(pos, explode_radius)
	if player.is_local:
		player.shake = 6.0
	Sfx.play("pulsar", pos, 2.0)
## Layered detonation visual: a bright flash, the main blast ring, a lingering
## outer shockwave, and a few scattered sparks -- a single ring read as flat.
func _spawn_burst(pos: Vector2, radius: float) -> void:
	var flash := RingFx.new()
	flash.position = pos
	flash.radius = 4.0
	flash.max_radius = radius * 0.55
	flash.life = 0.16
	flash.color = Color(1.0, 0.95, 1.0)
	player.get_parent().add_child(flash)
	var core := RingFx.new()
	core.position = pos
	core.radius = 16.0
	core.max_radius = radius
	core.life = 0.32
	core.color = Color(0.9, 0.35, 1.0)
	player.get_parent().add_child(core)
	var shock := RingFx.new()
	shock.position = pos
	shock.radius = radius * 0.4
	shock.max_radius = radius * 1.35
	shock.life = 0.5
	shock.color = Color(0.45, 0.15, 0.85)
	player.get_parent().add_child(shock)
	for i in 6:
		var spark := RingFx.new()
		spark.position = pos + Vector2.from_angle(randf() * TAU) * radius * 0.25
		spark.radius = 1.5
		spark.max_radius = 9.0
		spark.life = 0.22
		spark.color = Color(1.0, 0.8, 1.0)
		player.get_parent().add_child(spark)
func _draw() -> void:
	if player == null or player.downed:
		return
	var ball_r: float = cfg.ball_r * fuse_area()
	for p in ball_pos:
		var local: Vector2 = p - global_position
		draw_circle(local, ball_r, Color(0.75, 0.55, 1.0, 0.6))
		draw_circle(local, ball_r * 0.5, Color(0.45, 0.25, 0.85))
