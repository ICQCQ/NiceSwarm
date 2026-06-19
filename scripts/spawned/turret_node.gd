class_name TurretNode
extends Node2D
## Deployed sentry. `mode` selects what it does, driving the base Sentry Turret
## and every turret fusion. Projectile modes aim at the nearest enemy; emit modes
## (nova/mines/gravity/venom) act around themselves; beam/orbit run continuously.

var life := 5.0
var source_pid := -1  # scoreboard: credited to the turret's deployer
var source_weapon: WeaponBase
var owner_weapon_id := -1  # instance id of the deploying weapon; caps per-weapon, not global
var damage := 1.2
var target_range := 480.0  # Area
var fire_mult := 1.0   # Haste (lower = faster)
var proj_radius := 1.5
var mode := "bolt"
var area_mult := 1.0
var dur_mult := 1.0
var fire_cd := 0.2
var aim_angle := 0.0
var angle := 0.0       # orbit/beam sweep angle
var hit_cd := {}       # beam/orbit: per-enemy re-hit cooldown
var gun_cd := 0.0      # independent timer for the normal bolt gun (GUN_RETAINING_MODES)
var puddle_cd := 1.2   # venom mode: interval between dropped puddles (config-driven by the deploying weapon)
var burst_cd := 0.0    # flame mode: independent timer for the periodic ring-burst (see _burst_ring)
var burn_dps := 0.0    # flame mode: ignite dps, separate config knob from `damage` (set by the deploying fusion)
var burn_dur := 1.0    # flame mode: ignite duration

# Turret-fusion modes whose effect is NOT a fired bullet (ground deploys + AoE/chain).
# These KEEP the normal turret bolt gun firing on its own timer, on top of the effect —
# so e.g. a Mine Layer plants mines AND still shoots like a normal turret. Bullet modes
# (missile/frost/glaive + the plain bolt) and the continuous beam/orbit are unchanged.
const GUN_RETAINING_MODES := {
	"mines": true, "gravity": true, "venom": true,
	"nova": false, "lightning": false, "flame": false,
}
const BOLT_CD := 0.45  # normal turret bolt cadence (matches the default fire mode)
const GUN_RETAIN_SCALE := 0.35  # retained bolt gun on AoE/deploy modes is a bonus, not a 2nd full weapon
const FLAME_SPRAY_REACH := 190.0  # Flame Turret: cone spray reach (Area-scaled) — bigger base than the
# old 140 so an Area pick gains noticeably more range, not just a 1:1 token bump
const FLAME_BURST_RADIUS := 80.0  # Flame Turret: periodic ring-burst radius (Area-scaled)
const FLAME_BURST_CD := 2.0       # Flame Turret: ring-burst cadence (Haste-scaled), independent of the spray
const FLAME_BURST_SCALE := 0.6    # ring-burst is a bonus on top of the cone spray, not a 2nd full hit


func _ready() -> void:
	add_to_group("turrets")


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	queue_redraw()
	if mode == "flame":
		# the ring-burst runs on its own clock, independent of the cone spray's aim/fire_cd
		# below (it needs no target — it just catches whoever is close) so it keeps ticking
		# even while the turret is busy tracking a far-off target for the spray.
		burst_cd -= delta
		if burst_cd <= 0.0:
			burst_cd = FLAME_BURST_CD * fire_mult
			_burst_ring(FLAME_BURST_RADIUS * area_mult)
	if mode == "beam":
		_run_beam(delta)
		return
	if mode == "orbit":
		_run_orbit(delta)
		return
	# Bullet modes fire only on fire_cd; gun-retaining modes ALSO run the bolt gun on gun_cd.
	# .get(mode, false), not .has(mode) — the dict's value is what matters (nova/lightning/
	# flame are listed with `false` specifically to opt OUT of the retained gun; .has() would
	# return true for them too since the key exists, firing bullets they're not supposed to).
	var keeps_gun: bool = GUN_RETAINING_MODES.get(mode, false)
	if keeps_gun:
		gun_cd -= delta
	fire_cd -= delta
	if fire_cd > 0.0 and not (keeps_gun and gun_cd <= 0.0):
		return  # nothing ready to fire yet
	var target := _find_target()
	if target == null:
		if fire_cd <= 0.0:
			fire_cd = 0.1
		if keeps_gun and gun_cd <= 0.0:
			gun_cd = 0.1
		return
	aim_angle = (target.global_position - global_position).angle()
	if keeps_gun and gun_cd <= 0.0:
		_fire_bolt(GUN_RETAIN_SCALE)
		gun_cd = BOLT_CD * fire_mult
	if fire_cd <= 0.0:
		fire_cd = _emit(target) * fire_mult


## Fire one shot in the current mode; returns the base cooldown (pre-Haste).
func _emit(target: Node2D) -> float:
	var dir := Vector2.from_angle(aim_angle)
	var here := global_position
	match mode:
		"missile":
			var m := MissileProj.new()
			m.damage = damage
			m.splash = 70.0 * area_mult
			m.life = 4.0 * dur_mult
			m.velocity = dir * 320.0
			m.position = here
			m.source_pid = source_pid
			m.source_weapon = (source_weapon if is_instance_valid(source_weapon) else null)
			get_parent().add_child(m)
			Sfx.play("missile", here, -5.0)
			return 0.9
		"frost":
			var s := FrostShard.new()
			s.velocity = dir * 480.0
			s.damage = damage
			s.hit_radius = 7.0 * area_mult
			s.life = 1.4 * dur_mult
			s.slow_dur = 1.5 * dur_mult
			s.position = here
			s.source_pid = source_pid
			s.source_weapon = (source_weapon if is_instance_valid(source_weapon) else null)
			get_parent().add_child(s)
			Sfx.play("frost", here, -4.0)
			return 0.55
		"glaive":
			var g := GlaiveProj.new()
			g.velocity = dir * 400.0
			g.damage = damage
			g.hit_radius = 14.0 * area_mult
			g.position = here
			g.source_pid = source_pid
			g.source_weapon = (source_weapon if is_instance_valid(source_weapon) else null)
			get_parent().add_child(g)
			Sfx.play("glaive", here, -4.0)
			return 1.1
		"lightning":
			_chain(target)
			Sfx.play("lightning", here, -4.0)
			return 1.0
		"nova":
			_pulse(140.0 * area_mult)
			Sfx.play("nova", here, -4.0)
			return 1.6
		"flame":
			_spray(dir, FLAME_SPRAY_REACH * area_mult)
			Sfx.play("flame", here, -6.0)
			return 0.22
		"mines":
			var own_mines := 0
			for m2 in get_tree().get_nodes_in_group("mines"):
				if m2.owner_weapon_id == owner_weapon_id:
					own_mines += 1
			if own_mines < 6:  # per-deploying-weapon cap, not a shared global count
				var mn := MineNode.new()
				mn.owner_weapon_id = owner_weapon_id
				mn.damage = damage * 2.0
				mn.blast_radius = 90.0 * area_mult
				mn.trigger_radius = 50.0 * area_mult
				mn.life = 10.0 * dur_mult
				mn.position = here + Vector2(randf_range(-24.0, 24.0), randf_range(-24.0, 24.0))
				mn.source_pid = source_pid
				mn.source_weapon = (source_weapon if is_instance_valid(source_weapon) else null)
				get_parent().add_child(mn)
			return 1.4
		"gravity":
			var w := GravityWell.new()
			w.radius = 150.0 * area_mult
			w.damage = damage
			w.pull = 150.0
			w.life = 2.5 * dur_mult
			w.position = global_position
			w.source_pid = source_pid
			w.source_weapon = (source_weapon if is_instance_valid(source_weapon) else null)
			get_parent().add_child(w)
			Sfx.play("gravity", global_position, -3.0)
			return 3.0
		"venom":
			var pud := VenomPuddle.new()
			pud.radius = 55.0 * area_mult
			pud.damage = damage
			pud.max_life = 3.0 * dur_mult
			pud.life = pud.max_life
			pud.position = here + Vector2(randf_range(-20.0, 20.0), randf_range(-20.0, 20.0))
			pud.source_pid = source_pid
			pud.source_weapon = (source_weapon if is_instance_valid(source_weapon) else null)
			get_parent().add_child(pud)
			Sfx.play("venom", here, -4.0)
			return puddle_cd
		_:
			_fire_bolt()
			return BOLT_CD


## Fire one normal turret bolt toward aim_angle. Shared by the default bolt mode and the
## gun-retaining fusion modes (deploys/AoE that keep shooting — see GUN_RETAINING_MODES).
func _fire_bolt(scale := 1.0) -> void:
	var p := Projectile.new()
	p.velocity = Vector2.from_angle(aim_angle) * 520.0
	p.damage = damage * scale
	p.radius = proj_radius
	p.position = global_position
	p.source_pid = source_pid
	p.source_weapon = (source_weapon if is_instance_valid(source_weapon) else null)
	get_parent().add_child(p)
	Sfx.play("turret", global_position, -4.0)


func _pulse(radius: float) -> void:
	var fx := RingFx.new()
	fx.position = global_position
	fx.radius = 20.0
	fx.max_radius = radius
	fx.life = 0.3
	fx.color = Color(0.7, 0.7, 1.0)
	get_parent().add_child(fx)
	for e in EnemyGrid.near(global_position, radius):
		if global_position.distance_to(e.global_position) <= radius + e.radius:
			if is_instance_valid(source_weapon):
				source_weapon.damage_dealt += damage
			e.take_hit(damage, global_position, Enemy.DMG_ENERGY, source_pid)
			e.apply_push(global_position, 50.0 * area_mult)


## Flame Turret: a cone spray toward its target, the same shape as the base Flame
## Cone weapon (fixed reach + half-angle), plus a lingering burn. Unlike the base
## Flame Cone's ignite() (burn dps pinned to 0.3x the hit), burn_dps/burn_dur are
## their own config knob (cfg.burn_dps_ratio/burn_dur on the deploying fusion, see
## FusSentryBase) — independent of `damage`, tunable on their own.
func _spray(dir: Vector2, reach: float) -> void:
	for e in EnemyGrid.near(global_position, reach):
		var to: Vector2 = e.global_position - global_position
		if to.length() <= reach + e.radius and absf(dir.angle_to(to)) <= 0.6:
			if is_instance_valid(source_weapon):
				source_weapon.damage_dealt += damage
			e.take_hit(damage, null, Enemy.DMG_FIRE, source_pid)
			if burn_dps > 0.0:
				e.apply_burn(burn_dps, burn_dur, 1.0, source_pid)


## Flame Turret: a periodic omnidirectional ring-burst on top of the cone spray —
## no aim needed, so it catches anyone close by even outside the spray's cone. A
## bonus on top of the spray, not a second full hit (FLAME_BURST_SCALE), same
## spirit as the gun-retaining modes' GUN_RETAIN_SCALE — its burn is the same
## scaled-down fraction of the spray's own (separately configured) burn_dps.
func _burst_ring(radius: float) -> void:
	var fx := RingFx.new()
	fx.position = global_position
	fx.radius = 10.0
	fx.max_radius = radius
	fx.life = 0.3
	fx.color = Color(1.0, 0.5, 0.15)
	get_parent().add_child(fx)
	var burst_dmg := damage * FLAME_BURST_SCALE
	for e in EnemyGrid.near(global_position, radius):
		if global_position.distance_to(e.global_position) <= radius + e.radius:
			if is_instance_valid(source_weapon):
				source_weapon.damage_dealt += burst_dmg
			e.take_hit(burst_dmg, global_position, Enemy.DMG_FIRE, source_pid)
			if burn_dps > 0.0:
				e.apply_burn(burn_dps * FLAME_BURST_SCALE, burn_dur, 1.0, source_pid)


func _chain(first: Node2D) -> void:
	var pts: Array = [global_position]
	var visited := {}
	var cur: Node2D = first
	var hops := 4
	while cur != null and hops > 0:
		visited[cur.get_instance_id()] = true
		pts.append(cur.global_position)
		if is_instance_valid(source_weapon):
			source_weapon.damage_dealt += damage
		cur.take_hit(damage, null, Enemy.DMG_ENERGY, source_pid)
		hops -= 1
		cur = _nearest_unvisited(pts[pts.size() - 1], visited, 190.0)
	var fx := LightningFx.new()
	fx.points = pts
	get_parent().add_child(fx)


func _run_beam(delta: float) -> void:
	angle += 1.5 * delta
	aim_angle = angle
	var length := target_range * 0.7
	var dir := Vector2.from_angle(angle)
	_tick_cd(delta)
	for e in EnemyGrid.near(global_position, length):
		if hit_cd.has(e.get_instance_id()):
			continue
		var rel: Vector2 = e.global_position - global_position
		var along := clampf(rel.dot(dir), 0.0, length)
		if (dir * along).distance_to(rel) <= 7.0 + e.radius:
			if is_instance_valid(source_weapon):
				source_weapon.damage_dealt += damage
			e.take_hit(damage, global_position + dir * along, Enemy.DMG_ENERGY, source_pid)
			hit_cd[e.get_instance_id()] = 0.3 * fire_mult


func _run_orbit(delta: float) -> void:
	angle = fmod(angle + 3.0 / fire_mult * delta, TAU)
	_tick_cd(delta)
	var orbit_r := 55.0 * area_mult
	var blade_r := 11.0 * area_mult
	for e in EnemyGrid.near(global_position, orbit_r + blade_r):
		if hit_cd.has(e.get_instance_id()):
			continue
		for i in 3:
			var bp: Vector2 = global_position + Vector2.from_angle(angle + TAU * i / 3.0) * orbit_r
			if bp.distance_to(e.global_position) <= blade_r + e.radius:
				if is_instance_valid(source_weapon):
					source_weapon.damage_dealt += damage
				e.take_hit(damage, bp, Enemy.DMG_PHYS, source_pid)
				hit_cd[e.get_instance_id()] = 0.4 * fire_mult
				break


func _tick_cd(delta: float) -> void:
	for k in hit_cd.keys():
		hit_cd[k] -= delta
		if hit_cd[k] <= 0.0:
			hit_cd.erase(k)


func _nearest_unvisited(from: Vector2, visited: Dictionary, rng: float) -> Node2D:
	var best: Node2D = null
	var bd := rng * rng
	for e in EnemyGrid.near(from, rng):
		if visited.has(e.get_instance_id()):
			continue
		var d: float = from.distance_squared_to(e.global_position)
		if d < bd:
			bd = d
			best = e
	return best


func _find_target() -> Node2D:
	var best: Node2D = null
	var best_d := target_range * target_range
	for e in EnemyGrid.near(global_position, target_range):
		var d: float = global_position.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _draw() -> void:
	var tints := {
		"missile": Color(0.5, 0.4, 0.35), "frost": Color(0.4, 0.5, 0.6),
		"beam": Color(0.5, 0.4, 0.55), "glaive": Color(0.45, 0.55, 0.5),
		"lightning": Color(0.5, 0.55, 0.7), "nova": Color(0.5, 0.5, 0.7),
		"flame": Color(0.6, 0.4, 0.3), "mines": Color(0.5, 0.45, 0.35),
		"gravity": Color(0.45, 0.4, 0.55), "venom": Color(0.4, 0.55, 0.4),
		"orbit": Color(0.45, 0.5, 0.6),
	}
	var tint: Color = tints.get(mode, Color(0.4, 0.45, 0.5))
	draw_rect(Rect2(-9.0, -9.0, 18.0, 18.0), tint)
	if mode == "beam":
		var dir := Vector2.from_angle(angle)
		draw_line(Vector2.ZERO, dir * target_range * 0.7, Color(1.0, 0.4, 0.5, 0.25), 8.0)
		draw_line(Vector2.ZERO, dir * target_range * 0.7, Color(1.0, 0.6, 0.7), 2.5)
	elif mode == "orbit":
		var orbit_r := 55.0 * area_mult
		for i in 3:
			draw_circle(Vector2.from_angle(angle + TAU * i / 3.0) * orbit_r, 6.0 * area_mult, Color(0.7, 0.85, 1.0))
	elif mode == "flame":
		# a forward spray toward the target — same particle look as the base Flame Cone
		# weapon (random heat-colored circles in a cone, whiter near the nozzle)
		var reach := FLAME_SPRAY_REACH * area_mult
		for i in 5:
			var ang := aim_angle + randf_range(-0.5, 0.5)
			var dist := randf_range(reach * 0.25, reach)
			var p := Vector2.from_angle(ang) * dist
			var heat := 1.0 - dist / reach
			draw_circle(p, randf_range(3.0, 8.0), Color(1.0, 0.45 + 0.4 * heat, 0.15, randf_range(0.3, 0.6)))
	else:
		draw_line(Vector2.ZERO, Vector2.from_angle(aim_angle) * 14.0, Color(0.7, 0.75, 0.8), 4.0)
	var blink := fmod(life, 0.6) < 0.3 and life < 1.5
	draw_circle(Vector2.ZERO, 3.0, Color(1.0, 0.4, 0.3) if blink else Color(0.4, 1.0, 0.6))
