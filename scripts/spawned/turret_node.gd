class_name TurretNode
extends Node2D
## Deployed sentry. `mode` selects what it does, driving the base Sentry Turret
## and every turret fusion. Projectile modes aim at the nearest enemy; emit modes
## (nova/mines/gravity/venom) act around themselves; beam/orbit run continuously.

var life := 5.0
var source_pid := -1  # scoreboard: credited to the turret's deployer
var owner_weapon_id := -1  # instance id of the deploying weapon; caps per-weapon, not global
var damage := 1.2
var target_range := 480.0  # Area
var fire_mult := 1.0   # Haste (lower = faster)
var proj_radius := 5.0
var mode := "bolt"
var area_mult := 1.0
var dur_mult := 1.0
var fire_cd := 0.2
var aim_angle := 0.0
var angle := 0.0       # orbit/beam sweep angle
var hit_cd := {}       # beam/orbit: per-enemy re-hit cooldown


func _ready() -> void:
	add_to_group("turrets")


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	queue_redraw()
	if mode == "beam":
		_run_beam(delta)
		return
	if mode == "orbit":
		_run_orbit(delta)
		return
	fire_cd -= delta
	if fire_cd > 0.0:
		return
	var target := _find_target()
	if target == null:
		fire_cd = 0.1
		return
	aim_angle = (target.global_position - global_position).angle()
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
			get_parent().add_child(g)
			Sfx.play("glaive", here, -4.0)
			return 1.1
		"lightning":
			_chain(target)
			Sfx.play("lightning", here, -4.0)
			return 1.0
		"nova":
			_pulse(110.0 * area_mult)
			Sfx.play("nova", here, -4.0)
			return 1.6
		"flame":
			_cone(dir, (140.0 + 0.0) * area_mult)
			Sfx.play("flame", here, -6.0)
			return 0.18
		"mines":
			if get_tree().get_nodes_in_group("mines").size() < 6:
				var mn := MineNode.new()
				mn.damage = damage * 2.0
				mn.blast_radius = 90.0 * area_mult
				mn.trigger_radius = 50.0 * area_mult
				mn.life = 10.0 * dur_mult
				mn.position = here + Vector2(randf_range(-24.0, 24.0), randf_range(-24.0, 24.0))
				mn.source_pid = source_pid
				get_parent().add_child(mn)
			return 1.4
		"gravity":
			var w := GravityWell.new()
			w.radius = 150.0 * area_mult
			w.damage = damage
			w.pull = 150.0
			w.life = 2.5 * dur_mult
			w.position = target.global_position
			w.source_pid = source_pid
			get_parent().add_child(w)
			Sfx.play("gravity", target.global_position, -3.0)
			return 3.0
		"venom":
			var pud := VenomPuddle.new()
			pud.radius = 55.0 * area_mult
			pud.damage = damage
			pud.max_life = 3.0 * dur_mult
			pud.life = pud.max_life
			pud.position = here + Vector2(randf_range(-20.0, 20.0), randf_range(-20.0, 20.0))
			pud.source_pid = source_pid
			get_parent().add_child(pud)
			Sfx.play("venom", here, -4.0)
			return 1.2
		_:
			var p := Projectile.new()
			p.velocity = dir * 520.0
			p.damage = damage
			p.radius = proj_radius
			p.position = here
			p.source_pid = source_pid
			get_parent().add_child(p)
			Sfx.play("turret", here, -4.0)
			return 0.45


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
			e.take_hit(damage, global_position, Enemy.DMG_ENERGY, source_pid)


func _cone(dir: Vector2, reach: float) -> void:
	for e in EnemyGrid.near(global_position, reach):
		var to: Vector2 = e.global_position - global_position
		if to.length() <= reach + e.radius and absf(dir.angle_to(to)) <= 0.6:
			e.take_hit(damage, null, Enemy.DMG_FIRE, source_pid)


func _chain(first: Node2D) -> void:
	var pts: Array = [global_position]
	var visited := {}
	var cur: Node2D = first
	var hops := 4
	while cur != null and hops > 0:
		visited[cur.get_instance_id()] = true
		pts.append(cur.global_position)
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
	else:
		draw_line(Vector2.ZERO, Vector2.from_angle(aim_angle) * 14.0, Color(0.7, 0.75, 0.8), 4.0)
	var blink := fmod(life, 0.6) < 0.3 and life < 1.5
	draw_circle(Vector2.ZERO, 3.0, Color(1.0, 0.4, 0.3) if blink else Color(0.4, 1.0, 0.6))
