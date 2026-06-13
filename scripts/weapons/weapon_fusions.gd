class_name Fusions
extends RefCounted
## Fusion recipes: merging two MAXED weapons yields a DISTINCT new weapon (not the
## two running together). Each fusion is its own WeaponBase honoring the 4-stat
## contract (Power=damage, Haste=cadence, Area=size/reach, Duration=lifetime/burn).
##
## `INFO[key]` drives the [MERGE] upgrade text; `make(a, b)` builds the weapon.
## Keys are the two base weapon_ids sorted and joined with "|". Pairs without a
## signature recipe fall back to a generic combined fusion (see player.merge_weapons).

const INFO := {
	"bolt|nova": {"name": "Plasma Burst", "desc": "slugs that erupt into a blast on impact"},
	"frost|lightning": {"name": "Cryoshock", "desc": "a chain that freezes and burns every link"},
	"flame|venom": {"name": "Toxic Pyre", "desc": "a trail of burning toxic pools"},
	"gravity|nova": {"name": "Singularity", "desc": "a vortex that collapses into a detonation"},
	"mines|missiles": {"name": "Cluster Bomb", "desc": "mines that spray homing rockets on blast"},
	"laser|orbit": {"name": "Prism Halo", "desc": "rotating beam-spokes orbiting you"},
	"frost|glaive": {"name": "Glacial Edge", "desc": "boomerangs that freeze and bleed"},
	"bolt|lightning": {"name": "Railgun", "desc": "a piercing rail-shot that electrifies its whole line"},
	"flame|nova": {"name": "Supernova", "desc": "a huge blast that leaves a burning field"},
	"frost|orbit": {"name": "Frost Halo", "desc": "orbiting blades that freeze on contact"},
	"frost|gravity": {"name": "Glacier", "desc": "a slow, huge vortex that freezes everything inside"},
	"glaive|lightning": {"name": "Storm Disc", "desc": "boomerangs that arc lightning to nearby foes"},
	"flame|mines": {"name": "Napalm Mine", "desc": "mines that leave a burning pool on blast"},
	"missiles|nova": {"name": "Cluster Warhead", "desc": "rockets whose splash is a mini-nova"},
	"gravity|venom": {"name": "Black Bog", "desc": "a vortex that leaves a toxic pool where it forms"},
	"orbit|venom": {"name": "Toxic Halo", "desc": "orbiting blades that poison on contact"},
	"nova|orbit": {"name": "Pulsar", "desc": "orbiting blades that pulse a nova"},
	"bolt|frost": {"name": "Frost Lance", "desc": "a piercing volley of chilling lances"},
	"lightning|venom": {"name": "Plague Arc", "desc": "a chain that poisons every link"},
	"lightning|orbit": {"name": "Tesla Halo", "desc": "orbiting blades that zap nearby foes"},
	"flame|lightning": {"name": "Plasma Storm", "desc": "a searing cone that crackles with chained bolts"},
	"glaive|nova": {"name": "Cyclone", "desc": "whirling glaives around a pulsing core"},
	"missiles|turret": {"name": "Missile Battery", "desc": "a deployed launcher firing homing salvos"},
	"laser|turret": {"name": "Beam Sentry", "desc": "a deployed turret that sweeps a beam"},
	"frost|turret": {"name": "Cryo Sentry", "desc": "a deployed turret firing slowing shots"},
	"laser|nova": {"name": "Nova Beam", "desc": "sweeping beams that pulse a nova"},
	"bolt|missiles": {"name": "Barrage", "desc": "a hail of bolts laced with rocket salvos"},
	"nova|venom": {"name": "Toxic Nova", "desc": "a blast that leaves a poison pool"},
	"bolt|turret": {"name": "Gun Turret", "desc": "a deployed rapid-fire bolt turret"},
	"orbit|turret": {"name": "Halo Turret", "desc": "a deployed turret ringed with whirling blades"},
	"nova|turret": {"name": "Pulse Turret", "desc": "a deployed turret that pulses novas"},
	"glaive|turret": {"name": "Glaive Turret", "desc": "a deployed turret hurling boomerang glaives"},
	"lightning|turret": {"name": "Tesla Turret", "desc": "a deployed turret that chains lightning"},
	"flame|turret": {"name": "Flame Turret", "desc": "a deployed turret breathing a fire cone"},
	"mines|turret": {"name": "Mine Layer", "desc": "a deployed turret seeding proximity mines"},
	"gravity|turret": {"name": "Singularity Turret", "desc": "a deployed turret dropping gravity wells"},
	"turret|venom": {"name": "Toxic Turret", "desc": "a deployed turret pooling venom around it"},
	"frost|nova": {"name": "Absolute Zero", "desc": "a freezing blast that chills everything caught"},
	"flame|frost": {"name": "Thermal Shock", "desc": "a cone that burns and freezes for thermal stress"},
	"gravity|orbit": {"name": "Event Horizon", "desc": "blades that hold enemies in a crushing ring"},
	"glaive|gravity": {"name": "Vortex Blade", "desc": "glaives that drop a pulling vortex on the target"},
	"lightning|nova": {"name": "Thunderclap", "desc": "a blast that forks lightning out of every hit"},
	"mines|orbit": {"name": "Mine Halo", "desc": "orbiting blades that fling proximity mines"},
}


static func key(a: String, b: String) -> String:
	var ids := [a, b]
	ids.sort()
	return "|".join(ids)


static func info(a: String, b: String) -> Dictionary:
	return INFO.get(key(a, b), {})


static func make(a: String, b: String) -> WeaponBase:
	match key(a, b):
		"bolt|nova": return PlasmaBurst.new()
		"frost|lightning": return Cryoshock.new()
		"flame|venom": return ToxicPyre.new()
		"gravity|nova": return Singularity.new()
		"mines|missiles": return ClusterBomb.new()
		"laser|orbit": return PrismHalo.new()
		"frost|glaive": return GlacialEdge.new()
		"bolt|lightning": return Railgun.new()
		"flame|nova": return Supernova.new()
		"frost|orbit": return FrostHalo.new()
		"frost|gravity": return Glacier.new()
		"glaive|lightning": return StormDisc.new()
		"flame|mines": return NapalmMine.new()
		"missiles|nova": return ClusterWarhead.new()
		"gravity|venom": return BlackBog.new()
		"orbit|venom": return ToxicHalo.new()
		"nova|orbit": return Pulsar.new()
		"bolt|frost": return FrostLance.new()
		"lightning|venom": return PlagueArc.new()
		"lightning|orbit": return TeslaHalo.new()
		"flame|lightning": return PlasmaStorm.new()
		"glaive|nova": return Cyclone.new()
		"missiles|turret": return MissileBattery.new()
		"laser|turret": return BeamSentry.new()
		"frost|turret": return CryoSentry.new()
		"laser|nova": return NovaBeam.new()
		"bolt|missiles": return Barrage.new()
		"nova|venom": return ToxicNova.new()
		"bolt|turret": return GunTurret.new()
		"orbit|turret": return HaloTurret.new()
		"nova|turret": return PulseTurret.new()
		"glaive|turret": return GlaiveTurret.new()
		"lightning|turret": return TeslaTurret.new()
		"flame|turret": return FlameTurret.new()
		"mines|turret": return MineLayer.new()
		"gravity|turret": return SingularityTurret.new()
		"turret|venom": return ToxicTurret.new()
		"frost|nova": return AbsoluteZero.new()
		"flame|frost": return ThermalShock.new()
		"gravity|orbit": return EventHorizon.new()
		"glaive|gravity": return VortexBlade.new()
		"lightning|nova": return Thunderclap.new()
		"mines|orbit": return MineHalo.new()
	return null


# --- bolt + nova -------------------------------------------------------------
class PlasmaBurst extends WeaponBase:
	var cooldown := 0.6
	func _init() -> void:
		weapon_id = "fus_plasma"
		display_name = "Plasma Burst"
	func _physics_process(delta: float) -> void:
		if player == null or player.downed:
			return
		cooldown -= delta
		if cooldown > 0.0:
			return
		var target := player.nearest_enemy(650.0)
		if target == null:
			cooldown = 0.1
			return
		var dir := (target.global_position - player.global_position).normalized()
		var n := 1 + level
		var dmg := 2.0 * player.damage_mult * (1.0 + 0.4 * (level - 1))
		for i in n:
			var p := Projectile.new()
			p.velocity = dir.rotated(deg_to_rad(8.0) * (i - (n - 1) / 2.0)) * 480.0
			p.damage = dmg
			p.radius = 7.0 * player.area_mult
			p.life = 1.6 * player.duration_mult
			p.explode_radius = 70.0 * player.area_mult
			p.explode_damage = dmg * 0.8
			p.color = Color(1.0, 0.5, 0.9)
			p.position = player.global_position
			player.get_parent().add_child(p)
		Sfx.play("nova", player.global_position)
		cooldown = 0.9 * player.rate_mult


# --- frost + lightning -------------------------------------------------------
class Cryoshock extends WeaponBase:
	var cooldown := 0.8
	func _init() -> void:
		weapon_id = "fus_cryoshock"
		display_name = "Cryoshock"
	func _physics_process(delta: float) -> void:
		if player == null or player.downed:
			return
		cooldown -= delta
		if cooldown > 0.0:
			return
		var first := player.nearest_enemy(520.0)
		if first == null:
			cooldown = 0.15
			return
		var dmg := 2.5 * player.damage_mult * (1.0 + 0.4 * (level - 1))
		var chains := 3 + level
		var jump := 210.0 * player.area_mult
		var pts: Array = [player.global_position]
		var visited := {}
		var cur: Node2D = first
		while cur != null and chains > 0:
			visited[cur.get_instance_id()] = true
			pts.append(cur.global_position)
			cur.take_hit(dmg)
			cur.apply_slow(0.45, 1.6 * player.duration_mult)
			ignite(cur, dmg)
			chains -= 1
			cur = _next(pts[pts.size() - 1], visited, jump)
		var fx := LightningFx.new()
		fx.points = pts
		player.get_parent().add_child(fx)
		Sfx.play("lightning", player.global_position)
		cooldown = 1.8 * player.rate_mult
	func _next(from: Vector2, visited: Dictionary, jump: float) -> Node2D:
		var best: Node2D = null
		var bd := jump * jump
		for e in get_tree().get_nodes_in_group("enemies"):
			if visited.has(e.get_instance_id()):
				continue
			var d: float = from.distance_squared_to(e.global_position)
			if d < bd:
				bd = d
				best = e
		return best


# --- flame + venom -----------------------------------------------------------
class ToxicPyre extends WeaponBase:
	var drop := 0.0
	func _init() -> void:
		weapon_id = "fus_pyre"
		display_name = "Toxic Pyre"
	func _physics_process(delta: float) -> void:
		if player == null or player.downed:
			return
		drop -= delta
		if drop > 0.0:
			return
		drop = 0.3 * player.rate_mult
		var p := VenomPuddle.new()
		p.radius = (55.0 + 6.0 * (level - 1)) * player.area_mult
		p.damage = 1.0 * player.damage_mult * (1.0 + 0.4 * (level - 1))
		p.max_life = 3.0 * player.duration_mult
		p.life = p.max_life
		p.fiery = true
		p.burn_dps = 0.8 * player.damage_mult
		p.burn_dur = 1.2 * player.duration_mult
		p.position = player.global_position
		player.get_parent().add_child(p)
		Sfx.play("venom", player.global_position)


# --- gravity + nova ----------------------------------------------------------
class Singularity extends WeaponBase:
	var cooldown := 2.5
	func _init() -> void:
		weapon_id = "fus_singularity"
		display_name = "Singularity"
	func _physics_process(delta: float) -> void:
		if player == null or player.downed:
			return
		cooldown -= delta
		if cooldown > 0.0:
			return
		var target := player.nearest_enemy(700.0)
		if target == null:
			cooldown = 0.2
			return
		var w := GravityWell.new()
		w.radius = (170.0 + 15.0 * (level - 1)) * player.area_mult
		w.damage = 1.2 * player.damage_mult * (1.0 + 0.5 * (level - 1))
		w.pull = 210.0
		w.life = 2.5 * player.duration_mult
		w.detonate_damage = 6.0 * player.damage_mult * (1.0 + 0.5 * (level - 1))
		w.position = target.global_position
		player.get_parent().add_child(w)
		Sfx.play("gravity", target.global_position)
		cooldown = 5.5 * player.rate_mult


# --- mines + missiles --------------------------------------------------------
class ClusterBomb extends WeaponBase:
	var cooldown := 1.0
	func _init() -> void:
		weapon_id = "fus_cluster"
		display_name = "Cluster Bomb"
	func _physics_process(delta: float) -> void:
		if player == null or player.downed:
			return
		cooldown -= delta
		if cooldown > 0.0:
			return
		if get_tree().get_nodes_in_group("mines").size() >= 3 + level:
			cooldown = 0.2
			return
		var m := MineNode.new()
		m.damage = 6.0 * player.damage_mult * (1.0 + 0.5 * (level - 1))
		m.blast_radius = (110.0 + 15.0 * (level - 1)) * player.area_mult
		m.trigger_radius = 60.0 * player.area_mult
		m.life = 12.0 * player.duration_mult
		m.spawn_missiles = 2 + level
		m.position = player.global_position \
			+ Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 30.0))
		player.get_parent().add_child(m)
		Sfx.play("mine", player.global_position)
		cooldown = 2.0 * player.rate_mult


# --- laser + orbit -----------------------------------------------------------
class PrismHalo extends WeaponBase:
	const HIT_CD := 0.35
	var angle := 0.0
	var hit_cd := {}
	func _init() -> void:
		weapon_id = "fus_prism"
		display_name = "Prism Halo"
	func _physics_process(delta: float) -> void:
		if player == null or player.downed:
			queue_redraw()
			return
		angle = fmod(angle + 2.2 / player.rate_mult * delta, TAU)
		queue_redraw()
		var exp := []
		for k in hit_cd:
			hit_cd[k] -= delta
			if hit_cd[k] <= 0.0:
				exp.append(k)
		for k in exp:
			hit_cd.erase(k)
		var spokes := 1 + level
		var length := (150.0 + 20.0 * (level - 1)) * player.area_mult
		var dmg := 1.6 * player.damage_mult * (1.0 + 0.4 * (level - 1))
		for e in get_tree().get_nodes_in_group("enemies"):
			if hit_cd.has(e.get_instance_id()):
				continue
			var rel: Vector2 = e.global_position - global_position
			for s in spokes:
				var dir := Vector2.from_angle(angle + TAU * float(s) / spokes)
				var along := clampf(rel.dot(dir), 0.0, length)
				if (dir * along).distance_to(rel) <= 7.0 + e.radius:
					e.take_hit(dmg, global_position + dir * along)
					ignite(e, dmg)
					hit_cd[e.get_instance_id()] = HIT_CD * player.rate_mult
					Sfx.play("laser", e.global_position)
					break
	func _draw() -> void:
		if player == null or player.downed:
			return
		var spokes := 1 + level
		var length := (150.0 + 20.0 * (level - 1)) * player.area_mult
		for s in spokes:
			var dir := Vector2.from_angle(angle + TAU * float(s) / spokes)
			draw_line(Vector2.ZERO, dir * length, Color(0.8, 0.5, 1.0, 0.3), 7.0)
			draw_line(Vector2.ZERO, dir * length, Color(1.0, 0.85, 1.0), 2.5)
			draw_circle(dir * length, 6.0 * player.area_mult, Color(0.85, 0.6, 1.0))


# --- frost + glaive ----------------------------------------------------------
class GlacialEdge extends WeaponBase:
	var cooldown := 0.8
	func _init() -> void:
		weapon_id = "fus_glacial"
		display_name = "Glacial Edge"
	func _physics_process(delta: float) -> void:
		if player == null or player.downed:
			return
		cooldown -= delta
		if cooldown > 0.0:
			return
		var target := player.nearest_enemy(650.0)
		if target == null:
			cooldown = 0.1
			return
		var count := 2 + level
		var base := (target.global_position - player.global_position).normalized()
		for i in count:
			var g := GlaiveProj.new()
			g.player = player
			g.velocity = base.rotated(deg_to_rad(22.0) * (i - (count - 1) / 2.0)) * 430.0
			g.damage = 2.8 * player.damage_mult * (1.0 + 0.3 * (level - 1))
			g.hit_radius = 15.0 * player.area_mult
			g.slow_factor = 0.5
			g.position = player.global_position
			player.get_parent().add_child(g)
		Sfx.play("frost", player.global_position)
		cooldown = 1.5 * player.rate_mult


# --- bolt + lightning --------------------------------------------------------
class Railgun extends WeaponBase:
	var cooldown := 0.7
	func _init() -> void:
		weapon_id = "fus_railgun"
		display_name = "Railgun"
	func _physics_process(delta: float) -> void:
		if player == null or player.downed:
			return
		cooldown -= delta
		if cooldown > 0.0:
			return
		var target := player.nearest_enemy(750.0)
		if target == null:
			cooldown = 0.1
			return
		var dir := (target.global_position - player.global_position).normalized()
		var length := 600.0 * player.area_mult
		var width := 12.0 * player.area_mult
		var dmg := 3.0 * player.damage_mult * (1.0 + 0.4 * (level - 1))
		var origin := player.global_position
		for e in get_tree().get_nodes_in_group("enemies"):
			var rel: Vector2 = e.global_position - origin
			var along := rel.dot(dir)
			if along >= 0.0 and along <= length and (dir * along).distance_to(rel) <= width + e.radius:
				e.take_hit(dmg, origin)
				ignite(e, dmg)
		var fx := LightningFx.new()
		fx.points = [origin, origin + dir * length]
		player.get_parent().add_child(fx)
		Sfx.play("lightning", origin)
		cooldown = 1.3 * player.rate_mult


# --- flame + nova ------------------------------------------------------------
class Supernova extends WeaponBase:
	var cooldown := 1.8
	func _init() -> void:
		weapon_id = "fus_supernova"
		display_name = "Supernova"
	func _physics_process(delta: float) -> void:
		if player == null or player.downed:
			return
		cooldown -= delta
		if cooldown > 0.0:
			return
		var radius := (150.0 + 30.0 * (level - 1)) * player.area_mult
		var dmg := 3.5 * player.damage_mult * (1.0 + 0.5 * (level - 1))
		var hit_any := false
		for e in get_tree().get_nodes_in_group("enemies"):
			if global_position.distance_to(e.global_position) <= radius + e.radius:
				e.take_hit(dmg, global_position)
				ignite(e, dmg)
				hit_any = true
		if not hit_any:
			cooldown = 0.25
			return
		var fx := RingFx.new()
		fx.position = global_position
		fx.radius = 30.0
		fx.max_radius = radius
		fx.life = 0.4
		fx.color = Color(1.0, 0.5, 0.2)
		player.get_parent().add_child(fx)
		var pud := VenomPuddle.new()
		pud.radius = radius * 0.7
		pud.damage = dmg * 0.2
		pud.max_life = 2.0 * player.duration_mult
		pud.life = pud.max_life
		pud.fiery = true
		pud.burn_dps = dmg * 0.2
		pud.burn_dur = 1.0 * player.duration_mult
		pud.position = global_position
		player.get_parent().add_child(pud)
		Sfx.play("nova", global_position)
		cooldown = 3.2 * player.rate_mult


# --- frost + orbit -----------------------------------------------------------
class FrostHalo extends WeaponBase:
	const BLADE_R := 11.0
	const ORBIT_R := 78.0
	const HIT_CD := 0.5
	var angle := 0.0
	var hit_cd := {}
	func _init() -> void:
		weapon_id = "fus_frosthalo"
		display_name = "Frost Halo"
	func _physics_process(delta: float) -> void:
		if player == null or player.downed:
			queue_redraw()
			return
		angle = fmod(angle + 2.8 / player.rate_mult * delta, TAU)
		queue_redraw()
		var exp := []
		for k in hit_cd:
			hit_cd[k] -= delta
			if hit_cd[k] <= 0.0:
				exp.append(k)
		for k in exp:
			hit_cd.erase(k)
		var n := 2 + level
		var orbit_r := ORBIT_R * player.area_mult
		var blade_r := BLADE_R * player.area_mult
		var dmg := 2.0 * player.damage_mult * (1.0 + 0.4 * (level - 1))
		for e in get_tree().get_nodes_in_group("enemies"):
			if hit_cd.has(e.get_instance_id()):
				continue
			for i in n:
				var bp: Vector2 = global_position + Vector2.from_angle(angle + TAU * float(i) / n) * orbit_r
				if bp.distance_to(e.global_position) <= blade_r + e.radius:
					e.take_hit(dmg, bp)
					e.apply_slow(0.5, 1.2 * player.duration_mult)
					hit_cd[e.get_instance_id()] = HIT_CD * player.rate_mult
					break
	func _draw() -> void:
		if player == null or player.downed:
			return
		var n := 2 + level
		var orbit_r := ORBIT_R * player.area_mult
		var blade_r := BLADE_R * player.area_mult
		for i in n:
			var p := Vector2.from_angle(angle + TAU * float(i) / n) * orbit_r
			draw_circle(p, blade_r, Color(0.6, 0.85, 1.0))
			draw_circle(p, blade_r * 0.5, Color(0.85, 0.95, 1.0))


# --- frost + gravity ---------------------------------------------------------
class Glacier extends WeaponBase:
	var cooldown := 2.8
	func _init() -> void:
		weapon_id = "fus_glacier"
		display_name = "Glacier"
	func _physics_process(delta: float) -> void:
		if player == null or player.downed:
			return
		cooldown -= delta
		if cooldown > 0.0:
			return
		var target := player.nearest_enemy(700.0)
		if target == null:
			cooldown = 0.2
			return
		var w := GravityWell.new()
		w.radius = (200.0 + 20.0 * (level - 1)) * player.area_mult
		w.damage = 1.0 * player.damage_mult * (1.0 + 0.5 * (level - 1))
		w.pull = 120.0
		w.life = 3.0 * player.duration_mult
		w.freeze = true
		w.position = target.global_position
		player.get_parent().add_child(w)
		Sfx.play("frost", target.global_position)
		cooldown = 6.0 * player.rate_mult


# --- glaive + lightning ------------------------------------------------------
class StormDisc extends WeaponBase:
	var cooldown := 0.9
	func _init() -> void:
		weapon_id = "fus_storm"
		display_name = "Storm Disc"
	func _physics_process(delta: float) -> void:
		if player == null or player.downed:
			return
		cooldown -= delta
		if cooldown > 0.0:
			return
		var target := player.nearest_enemy(650.0)
		if target == null:
			cooldown = 0.1
			return
		var count := 1 + level
		var base := (target.global_position - player.global_position).normalized()
		var dmg := 2.5 * player.damage_mult * (1.0 + 0.3 * (level - 1))
		for i in count:
			var g := GlaiveProj.new()
			g.player = player
			g.velocity = base.rotated(deg_to_rad(24.0) * (i - (count - 1) / 2.0)) * 430.0
			g.damage = dmg
			g.hit_radius = 14.0 * player.area_mult
			g.arc_damage = dmg * 0.6
			g.arc_range = 150.0 * player.area_mult
			g.position = player.global_position
			player.get_parent().add_child(g)
		Sfx.play("lightning", player.global_position)
		cooldown = 1.6 * player.rate_mult


# --- flame + mines -----------------------------------------------------------
class NapalmMine extends WeaponBase:
	var cooldown := 1.1
	func _init() -> void:
		weapon_id = "fus_napalm"
		display_name = "Napalm Mine"
	func _physics_process(delta: float) -> void:
		if player == null or player.downed:
			return
		cooldown -= delta
		if cooldown > 0.0:
			return
		if get_tree().get_nodes_in_group("mines").size() >= 3 + level:
			cooldown = 0.2
			return
		var dmg := 6.0 * player.damage_mult * (1.0 + 0.5 * (level - 1))
		var m := MineNode.new()
		m.damage = dmg
		m.blast_radius = (100.0 + 15.0 * (level - 1)) * player.area_mult
		m.trigger_radius = 55.0 * player.area_mult
		m.life = 12.0 * player.duration_mult
		m.fire_dps = dmg * 0.25
		m.fire_radius = 90.0 * player.area_mult
		m.fire_dur = 2.0 * player.duration_mult
		m.position = player.global_position \
			+ Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 30.0))
		player.get_parent().add_child(m)
		Sfx.play("mine", player.global_position)
		cooldown = 2.0 * player.rate_mult


# --- missiles + nova ---------------------------------------------------------
class ClusterWarhead extends WeaponBase:
	var cooldown := 1.4
	func _init() -> void:
		weapon_id = "fus_warhead"
		display_name = "Cluster Warhead"
	func _physics_process(delta: float) -> void:
		if player == null or player.downed:
			return
		cooldown -= delta
		if cooldown > 0.0:
			return
		if player.nearest_enemy(800.0) == null:
			cooldown = 0.2
			return
		var count := 1 + level
		var dmg := 3.0 * player.damage_mult * (1.0 + 0.3 * (level - 1))
		for i in count:
			var m := MissileProj.new()
			m.damage = dmg
			m.splash = 130.0 * player.area_mult  # mini-nova blast
			m.life = 4.0 * player.duration_mult
			m.velocity = Vector2.from_angle(randf() * TAU) * 300.0
			m.position = player.global_position
			player.get_parent().add_child(m)
		Sfx.play("missile", player.global_position)
		cooldown = 2.6 * player.rate_mult


# --- gravity + venom ---------------------------------------------------------
class BlackBog extends WeaponBase:
	var cooldown := 2.6
	func _init() -> void:
		weapon_id = "fus_blackbog"
		display_name = "Black Bog"
	func _physics_process(delta: float) -> void:
		if player == null or player.downed:
			return
		cooldown -= delta
		if cooldown > 0.0:
			return
		var target := player.nearest_enemy(700.0)
		if target == null:
			cooldown = 0.2
			return
		var r := (170.0 + 15.0 * (level - 1)) * player.area_mult
		var life := 3.0 * player.duration_mult
		var dmg := player.damage_mult * (1.0 + 0.4 * (level - 1))
		var w := GravityWell.new()
		w.radius = r
		w.damage = 0.8 * dmg
		w.pull = 160.0
		w.life = life
		w.position = target.global_position
		player.get_parent().add_child(w)
		var pud := VenomPuddle.new()
		pud.radius = r * 0.9
		pud.damage = 1.0 * dmg
		pud.max_life = life
		pud.life = life
		pud.position = target.global_position
		player.get_parent().add_child(pud)
		Sfx.play("gravity", target.global_position)
		cooldown = 5.5 * player.rate_mult


# --- orbit + venom -----------------------------------------------------------
class ToxicHalo extends WeaponBase:
	const BLADE_R := 11.0
	const ORBIT_R := 80.0
	const HIT_CD := 0.5
	var angle := 0.0
	var hit_cd := {}
	func _init() -> void:
		weapon_id = "fus_toxhalo"
		display_name = "Toxic Halo"
	func _physics_process(delta: float) -> void:
		if player == null or player.downed:
			queue_redraw()
			return
		angle = fmod(angle + 2.6 / player.rate_mult * delta, TAU)
		queue_redraw()
		var expired := []
		for k in hit_cd:
			hit_cd[k] -= delta
			if hit_cd[k] <= 0.0:
				expired.append(k)
		for k in expired:
			hit_cd.erase(k)
		var n := 2 + level
		var orbit_r := ORBIT_R * player.area_mult
		var blade_r := BLADE_R * player.area_mult
		var dmg := 2.0 * player.damage_mult * (1.0 + 0.4 * (level - 1))
		for e in get_tree().get_nodes_in_group("enemies"):
			if hit_cd.has(e.get_instance_id()):
				continue
			for i in n:
				var bp: Vector2 = global_position + Vector2.from_angle(angle + TAU * float(i) / n) * orbit_r
				if bp.distance_to(e.global_position) <= blade_r + e.radius:
					e.take_hit(dmg, bp)
					e.apply_burn(dmg * 0.35, 1.5 * player.duration_mult)  # poison
					hit_cd[e.get_instance_id()] = HIT_CD * player.rate_mult
					break
	func _draw() -> void:
		if player == null or player.downed:
			return
		var n := 2 + level
		var orbit_r := ORBIT_R * player.area_mult
		var blade_r := BLADE_R * player.area_mult
		for i in n:
			var p := Vector2.from_angle(angle + TAU * float(i) / n) * orbit_r
			draw_circle(p, blade_r, Color(0.5, 0.85, 0.4))
			draw_circle(p, blade_r * 0.5, Color(0.7, 1.0, 0.5))


# --- nova + orbit ------------------------------------------------------------
class Pulsar extends WeaponBase:
	const ORBIT_R := 80.0
	const BLADE_R := 11.0
	const HIT_CD := 0.45
	var angle := 0.0
	var hit_cd := {}
	var nova_cd := 0.0
	func _init() -> void:
		weapon_id = "fus_pulsar"
		display_name = "Pulsar"
	func _physics_process(delta: float) -> void:
		if player == null or player.downed:
			queue_redraw()
			return
		angle = fmod(angle + 3.0 / player.rate_mult * delta, TAU)
		queue_redraw()
		var expired := []
		for k in hit_cd:
			hit_cd[k] -= delta
			if hit_cd[k] <= 0.0:
				expired.append(k)
		for k in expired:
			hit_cd.erase(k)
		var n := 2 + level
		var orbit_r := ORBIT_R * player.area_mult
		var blade_r := BLADE_R * player.area_mult
		var dmg := 2.0 * player.damage_mult * (1.0 + 0.4 * (level - 1))
		for e in get_tree().get_nodes_in_group("enemies"):
			if hit_cd.has(e.get_instance_id()):
				continue
			for i in n:
				var bp: Vector2 = global_position + Vector2.from_angle(angle + TAU * float(i) / n) * orbit_r
				if bp.distance_to(e.global_position) <= blade_r + e.radius:
					e.take_hit(dmg, bp)
					hit_cd[e.get_instance_id()] = HIT_CD * player.rate_mult
					break
		nova_cd -= delta
		if nova_cd <= 0.0:
			var radius := (120.0 + 25.0 * (level - 1)) * player.area_mult
			var ndmg := 2.5 * player.damage_mult * (1.0 + 0.4 * (level - 1))
			var any := false
			for e in get_tree().get_nodes_in_group("enemies"):
				if global_position.distance_to(e.global_position) <= radius + e.radius:
					e.take_hit(ndmg, global_position, Enemy.DMG_ENERGY)
					ignite(e, ndmg)
					any = true
			if any:
				var fx := RingFx.new()
				fx.position = global_position
				fx.radius = 25.0
				fx.max_radius = radius
				fx.life = 0.35
				fx.color = Color(0.7, 0.6, 1.0)
				player.get_parent().add_child(fx)
				Sfx.play("nova", global_position)
				nova_cd = 2.5 * player.rate_mult
			else:
				nova_cd = 0.3
	func _draw() -> void:
		if player == null or player.downed:
			return
		var n := 2 + level
		var orbit_r := ORBIT_R * player.area_mult
		var blade_r := BLADE_R * player.area_mult
		for i in n:
			var p := Vector2.from_angle(angle + TAU * float(i) / n) * orbit_r
			draw_circle(p, blade_r, Color(0.7, 0.7, 1.0))
			draw_circle(p, blade_r * 0.5, Color(0.4, 0.4, 0.8))


# --- bolt + frost ------------------------------------------------------------
class FrostLance extends WeaponBase:
	var cooldown := 0.5
	func _init() -> void:
		weapon_id = "fus_frostlance"
		display_name = "Frost Lance"
	func _physics_process(delta: float) -> void:
		if player == null or player.downed:
			return
		cooldown -= delta
		if cooldown > 0.0:
			return
		var target := player.nearest_enemy(700.0)
		if target == null:
			cooldown = 0.1
			return
		var base := (target.global_position - player.global_position).normalized()
		var count := 2 + level
		for i in count:
			var s := FrostShard.new()
			s.velocity = base.rotated(deg_to_rad(6.0 * (i - (count - 1) / 2.0))) * 620.0
			s.damage = 2.2 * player.damage_mult * (1.0 + 0.3 * (level - 1))
			s.hit_radius = 8.0 * player.area_mult
			s.life = 1.6 * player.duration_mult
			s.slow_dur = 1.4 * player.duration_mult
			s.pierce_left = 4
			s.position = player.global_position
			player.get_parent().add_child(s)
		Sfx.play("frost", player.global_position)
		cooldown = 1.0 * player.rate_mult


# --- lightning + venom -------------------------------------------------------
class PlagueArc extends WeaponBase:
	var cooldown := 0.9
	func _init() -> void:
		weapon_id = "fus_plague"
		display_name = "Plague Arc"
	func _physics_process(delta: float) -> void:
		if player == null or player.downed:
			return
		cooldown -= delta
		if cooldown > 0.0:
			return
		var first := player.nearest_enemy(520.0)
		if first == null:
			cooldown = 0.15
			return
		var dmg := 2.2 * player.damage_mult * (1.0 + 0.35 * (level - 1))
		var chains := 3 + level
		var pts: Array = [player.global_position]
		var visited := {}
		var cur: Node2D = first
		while cur != null and chains > 0:
			visited[cur.get_instance_id()] = true
			pts.append(cur.global_position)
			cur.take_hit(dmg, null, Enemy.DMG_ENERGY)
			cur.apply_burn(dmg * 0.4, 2.0 * player.duration_mult)  # virulent poison
			chains -= 1
			cur = _next(pts[pts.size() - 1], visited)
		var fx := LightningFx.new()
		fx.points = pts
		player.get_parent().add_child(fx)
		Sfx.play("lightning", player.global_position)
		cooldown = 1.9 * player.rate_mult
	func _next(from: Vector2, visited: Dictionary) -> Node2D:
		var best: Node2D = null
		var bd := 210.0 * 210.0
		for e in get_tree().get_nodes_in_group("enemies"):
			if visited.has(e.get_instance_id()):
				continue
			var d: float = from.distance_squared_to(e.global_position)
			if d < bd:
				bd = d
				best = e
		return best


# --- lightning + orbit -------------------------------------------------------
class TeslaHalo extends WeaponBase:
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
		angle = fmod(angle + 3.0 / player.rate_mult * delta, TAU)
		queue_redraw()
		var expired := []
		for k in hit_cd:
			hit_cd[k] -= delta
			if hit_cd[k] <= 0.0:
				expired.append(k)
		for k in expired:
			hit_cd.erase(k)
		var n := 2 + level
		var orbit_r := ORBIT_R * player.area_mult
		var blade_r := BLADE_R * player.area_mult
		var dmg := 2.0 * player.damage_mult * (1.0 + 0.4 * (level - 1))
		for e in get_tree().get_nodes_in_group("enemies"):
			if hit_cd.has(e.get_instance_id()):
				continue
			for i in n:
				var bp: Vector2 = global_position + Vector2.from_angle(angle + TAU * float(i) / n) * orbit_r
				if bp.distance_to(e.global_position) <= blade_r + e.radius:
					e.take_hit(dmg, bp, Enemy.DMG_ENERGY)
					ignite(e, dmg)
					hit_cd[e.get_instance_id()] = HIT_CD * player.rate_mult
					_zap(e, dmg)
					break
	func _zap(src: Node2D, dmg: float) -> void:
		var best: Node2D = null
		var bd := 170.0 * 170.0
		for e in get_tree().get_nodes_in_group("enemies"):
			if e == src:
				continue
			var d: float = src.global_position.distance_squared_to(e.global_position)
			if d < bd:
				bd = d
				best = e
		if best == null:
			return
		best.take_hit(dmg * 0.7, src.global_position, Enemy.DMG_ENERGY)
		var fx := LightningFx.new()
		fx.points = [src.global_position, best.global_position]
		player.get_parent().add_child(fx)
	func _draw() -> void:
		if player == null or player.downed:
			return
		var n := 2 + level
		var orbit_r := ORBIT_R * player.area_mult
		var blade_r := BLADE_R * player.area_mult
		for i in n:
			var p := Vector2.from_angle(angle + TAU * float(i) / n) * orbit_r
			draw_circle(p, blade_r, Color(0.6, 0.8, 1.0))
			draw_circle(p, blade_r * 0.5, Color(0.9, 0.95, 1.0))


# --- flame + lightning -------------------------------------------------------
class PlasmaStorm extends WeaponBase:
	const TICK := 0.14
	const HALF := 0.62
	var tick := 0.0
	var bolt_cd := 0.0
	func _init() -> void:
		weapon_id = "fus_plasmastorm"
		display_name = "Plasma Storm"
	func _physics_process(delta: float) -> void:
		queue_redraw()
		if player == null or player.downed:
			return
		var reach := (160.0 + 12.0 * (level - 1)) * player.area_mult
		tick -= delta
		if tick <= 0.0:
			tick = TICK * player.rate_mult
			var dmg := 0.7 * player.damage_mult * (1.0 + 0.4 * (level - 1))
			for e in get_tree().get_nodes_in_group("enemies"):
				var to: Vector2 = e.global_position - player.global_position
				if to.length() <= reach + e.radius and absf(player.facing.angle_to(to)) <= HALF:
					e.take_hit(dmg, null, Enemy.DMG_FIRE)
					ignite(e, dmg)
			Sfx.play("flame", player.global_position)
		bolt_cd -= delta
		if bolt_cd <= 0.0:
			var first := player.nearest_enemy(reach + 60.0)
			if first != null:
				var bdmg := 2.2 * player.damage_mult * (1.0 + 0.4 * (level - 1))
				var chains := 2 + level
				var pts: Array = [player.global_position]
				var visited := {}
				var cur: Node2D = first
				while cur != null and chains > 0:
					visited[cur.get_instance_id()] = true
					pts.append(cur.global_position)
					cur.take_hit(bdmg, null, Enemy.DMG_ENERGY)
					chains -= 1
					cur = _next(pts[pts.size() - 1], visited)
				var fx := LightningFx.new()
				fx.points = pts
				player.get_parent().add_child(fx)
				Sfx.play("lightning", player.global_position)
				bolt_cd = 1.4 * player.rate_mult
			else:
				bolt_cd = 0.2
	func _next(from: Vector2, visited: Dictionary) -> Node2D:
		var best: Node2D = null
		var bd := 200.0 * 200.0
		for e in get_tree().get_nodes_in_group("enemies"):
			if visited.has(e.get_instance_id()):
				continue
			var d: float = from.distance_squared_to(e.global_position)
			if d < bd:
				bd = d
				best = e
		return best
	func _draw() -> void:
		if player == null or player.downed:
			return
		var reach := (160.0 + 12.0 * (level - 1)) * player.area_mult
		var base_a := player.facing.angle()
		for i in 7:
			var ang := base_a + randf_range(-HALF * 0.8, HALF * 0.8)
			var dist := randf_range(reach * 0.25, reach)
			draw_circle(Vector2.from_angle(ang) * dist, randf_range(4.0, 10.0),
				Color(0.7, 0.6, 1.0, randf_range(0.3, 0.6)))


# --- glaive + nova -----------------------------------------------------------
class Cyclone extends WeaponBase:
	var cooldown := 0.8
	var nova_cd := 0.0
	func _init() -> void:
		weapon_id = "fus_cyclone"
		display_name = "Cyclone"
	func _physics_process(delta: float) -> void:
		if player == null or player.downed:
			return
		cooldown -= delta
		if cooldown <= 0.0:
			var target := player.nearest_enemy(650.0)
			if target != null:
				var count := 2 + level
				var base := (target.global_position - player.global_position).normalized()
				for i in count:
					var g := GlaiveProj.new()
					g.player = player
					g.velocity = base.rotated(TAU * float(i) / count) * 380.0
					g.damage = 2.5 * player.damage_mult * (1.0 + 0.3 * (level - 1))
					g.hit_radius = 14.0 * player.area_mult
					g.position = player.global_position
					player.get_parent().add_child(g)
				Sfx.play("glaive", player.global_position)
				cooldown = 1.5 * player.rate_mult
			else:
				cooldown = 0.1
		nova_cd -= delta
		if nova_cd <= 0.0:
			var radius := (120.0 + 22.0 * (level - 1)) * player.area_mult
			var ndmg := 2.5 * player.damage_mult * (1.0 + 0.4 * (level - 1))
			var any := false
			for e in get_tree().get_nodes_in_group("enemies"):
				if player.global_position.distance_to(e.global_position) <= radius + e.radius:
					e.take_hit(ndmg, player.global_position, Enemy.DMG_ENERGY)
					ignite(e, ndmg)
					any = true
			if any:
				var fx := RingFx.new()
				fx.position = player.global_position
				fx.radius = 25.0
				fx.max_radius = radius
				fx.life = 0.35
				fx.color = Color(0.7, 0.9, 1.0)
				player.get_parent().add_child(fx)
				Sfx.play("nova", player.global_position)
				nova_cd = 2.8 * player.rate_mult
			else:
				nova_cd = 0.3


# --- deployed turret variants (turret + X) -----------------------------------
class _Sentry extends WeaponBase:
	var cooldown := 1.5
	var mode := "bolt"
	var dmg_base := 1.5
	func _deploy_cap() -> int:
		return 1 + (1 if level >= 2 else 0)
	func _physics_process(delta: float) -> void:
		if player == null or player.downed:
			return
		cooldown -= delta
		if cooldown > 0.0:
			return
		if get_tree().get_nodes_in_group("turrets").size() >= _deploy_cap():
			cooldown = 0.3
			return
		var t := TurretNode.new()
		t.mode = mode
		t.life = (6.0 + 0.5 * level) * player.duration_mult
		t.damage = dmg_base * player.damage_mult * (1.0 + 0.3 * (level - 1))
		t.target_range = 520.0 * player.area_mult
		t.area_mult = player.area_mult
		t.dur_mult = player.duration_mult
		t.fire_mult = player.rate_mult
		t.position = player.global_position
		player.get_parent().add_child(t)
		Sfx.play("turret_deploy", player.global_position)
		cooldown = 6.5 * player.rate_mult

class MissileBattery extends _Sentry:
	func _init() -> void:
		weapon_id = "fus_missilebattery"
		display_name = "Missile Battery"
		mode = "missile"
		dmg_base = 3.0

class BeamSentry extends _Sentry:
	func _init() -> void:
		weapon_id = "fus_beamsentry"
		display_name = "Beam Sentry"
		mode = "beam"
		dmg_base = 1.2

class CryoSentry extends _Sentry:
	func _init() -> void:
		weapon_id = "fus_cryosentry"
		display_name = "Cryo Sentry"
		mode = "frost"
		dmg_base = 1.8


# --- laser + nova ------------------------------------------------------------
class NovaBeam extends WeaponBase:
	const SPIN := 1.4
	const HIT_CD := 0.3
	var angle := 0.0
	var hit_cd := {}
	var nova_cd := 0.0
	func _init() -> void:
		weapon_id = "fus_novabeam"
		display_name = "Nova Beam"
	func _physics_process(delta: float) -> void:
		if player == null or player.downed:
			queue_redraw()
			return
		angle = fmod(angle + SPIN / player.rate_mult * delta, TAU)
		queue_redraw()
		var expired := []
		for k in hit_cd:
			hit_cd[k] -= delta
			if hit_cd[k] <= 0.0:
				expired.append(k)
		for k in expired:
			hit_cd.erase(k)
		var beams := 1 + level
		var length := (240.0 + 30.0 * (level - 1)) * player.area_mult
		var dmg := 1.4 * player.damage_mult * (1.0 + 0.4 * (level - 1))
		for e in get_tree().get_nodes_in_group("enemies"):
			if hit_cd.has(e.get_instance_id()):
				continue
			var rel: Vector2 = e.global_position - global_position
			for b in beams:
				var dir := Vector2.from_angle(angle + TAU * float(b) / beams)
				var along := clampf(rel.dot(dir), 0.0, length)
				if (dir * along).distance_to(rel) <= 6.0 + e.radius:
					e.take_hit(dmg, global_position + dir * along, Enemy.DMG_ENERGY)
					ignite(e, dmg)
					hit_cd[e.get_instance_id()] = HIT_CD * player.rate_mult
					break
		nova_cd -= delta
		if nova_cd <= 0.0:
			var radius := (110.0 + 22.0 * (level - 1)) * player.area_mult
			var ndmg := 2.5 * player.damage_mult * (1.0 + 0.4 * (level - 1))
			var any := false
			for e in get_tree().get_nodes_in_group("enemies"):
				if global_position.distance_to(e.global_position) <= radius + e.radius:
					e.take_hit(ndmg, global_position, Enemy.DMG_ENERGY)
					any = true
			if any:
				var fx := RingFx.new()
				fx.position = global_position
				fx.radius = 25.0
				fx.max_radius = radius
				fx.life = 0.35
				fx.color = Color(1.0, 0.6, 0.7)
				player.get_parent().add_child(fx)
				Sfx.play("nova", global_position)
				nova_cd = 2.6 * player.rate_mult
			else:
				nova_cd = 0.3
	func _draw() -> void:
		if player == null or player.downed:
			return
		var beams := 1 + level
		var length := (240.0 + 30.0 * (level - 1)) * player.area_mult
		for b in beams:
			var dir := Vector2.from_angle(angle + TAU * float(b) / beams)
			draw_line(Vector2.ZERO, dir * length, Color(1.0, 0.4, 0.5, 0.25), 9.0)
			draw_line(Vector2.ZERO, dir * length, Color(1.0, 0.6, 0.7), 3.0)


# --- bolt + missiles ---------------------------------------------------------
class Barrage extends WeaponBase:
	var cooldown := 0.3
	var salvo := 0
	func _init() -> void:
		weapon_id = "fus_barrage"
		display_name = "Barrage"
	func _physics_process(delta: float) -> void:
		if player == null or player.downed:
			return
		cooldown -= delta
		if cooldown > 0.0:
			return
		var target := player.nearest_enemy(700.0)
		if target == null:
			cooldown = 0.1
			return
		var base := (target.global_position - player.global_position).normalized()
		var dmg := 1.0 * player.damage_mult * (1.0 + 0.3 * (level - 1))
		for i in (1 + level):
			var p := Projectile.new()
			p.velocity = base.rotated(deg_to_rad(9.0) * (i - level / 2.0)) * 560.0
			p.damage = dmg
			p.radius = 5.0 * player.area_mult
			p.life = 1.6 * player.duration_mult
			p.position = player.global_position
			player.get_parent().add_child(p)
		Sfx.play("bolt", player.global_position)
		salvo += 1
		if salvo >= 4:  # periodic rocket salvo woven into the hail of bolts
			salvo = 0
			for i in (1 + level):
				var m := MissileProj.new()
				m.damage = 3.0 * player.damage_mult * (1.0 + 0.3 * (level - 1))
				m.splash = 70.0 * player.area_mult
				m.life = 4.0 * player.duration_mult
				m.velocity = Vector2.from_angle(randf() * TAU) * 300.0
				m.position = player.global_position
				player.get_parent().add_child(m)
			Sfx.play("missile", player.global_position)
		cooldown = 0.45 * player.rate_mult


# --- nova + venom ------------------------------------------------------------
class ToxicNova extends WeaponBase:
	var cooldown := 1.6
	func _init() -> void:
		weapon_id = "fus_toxicnova"
		display_name = "Toxic Nova"
	func _physics_process(delta: float) -> void:
		if player == null or player.downed:
			return
		cooldown -= delta
		if cooldown > 0.0:
			return
		var radius := (130.0 + 28.0 * (level - 1)) * player.area_mult
		var dmg := 3.0 * player.damage_mult * (1.0 + 0.4 * (level - 1))
		var any := false
		for e in get_tree().get_nodes_in_group("enemies"):
			if global_position.distance_to(e.global_position) <= radius + e.radius:
				e.take_hit(dmg, global_position)
				e.apply_burn(dmg * 0.3, 1.5 * player.duration_mult)
				any = true
		if not any:
			cooldown = 0.25
			return
		var fx := RingFx.new()
		fx.position = global_position
		fx.radius = 25.0
		fx.max_radius = radius
		fx.life = 0.4
		fx.color = Color(0.5, 0.9, 0.4)
		player.get_parent().add_child(fx)
		var pud := VenomPuddle.new()
		pud.radius = radius * 0.7
		pud.damage = dmg * 0.25
		pud.max_life = 2.5 * player.duration_mult
		pud.life = pud.max_life
		pud.position = global_position
		player.get_parent().add_child(pud)
		Sfx.play("nova", global_position)
		cooldown = 3.0 * player.rate_mult


# --- turret + every other weapon: deployed sentry variants --------------------
class GunTurret extends _Sentry:
	func _init() -> void:
		weapon_id = "fus_gunturret"
		display_name = "Gun Turret"
		mode = "bolt"
		dmg_base = 1.5

class HaloTurret extends _Sentry:
	func _init() -> void:
		weapon_id = "fus_haloturret"
		display_name = "Halo Turret"
		mode = "orbit"
		dmg_base = 2.0

class PulseTurret extends _Sentry:
	func _init() -> void:
		weapon_id = "fus_pulseturret"
		display_name = "Pulse Turret"
		mode = "nova"
		dmg_base = 2.5

class GlaiveTurret extends _Sentry:
	func _init() -> void:
		weapon_id = "fus_glaiveturret"
		display_name = "Glaive Turret"
		mode = "glaive"
		dmg_base = 2.5

class TeslaTurret extends _Sentry:
	func _init() -> void:
		weapon_id = "fus_teslaturret"
		display_name = "Tesla Turret"
		mode = "lightning"
		dmg_base = 2.0

class FlameTurret extends _Sentry:
	func _init() -> void:
		weapon_id = "fus_flameturret"
		display_name = "Flame Turret"
		mode = "flame"
		dmg_base = 0.8

class MineLayer extends _Sentry:
	func _init() -> void:
		weapon_id = "fus_minelayer"
		display_name = "Mine Layer"
		mode = "mines"
		dmg_base = 3.0

class SingularityTurret extends _Sentry:
	func _init() -> void:
		weapon_id = "fus_singturret"
		display_name = "Singularity Turret"
		mode = "gravity"
		dmg_base = 1.2

class ToxicTurret extends _Sentry:
	func _init() -> void:
		weapon_id = "fus_toxturret"
		display_name = "Toxic Turret"
		mode = "venom"
		dmg_base = 1.0


# --- frost + nova: a freezing nova -------------------------------------------
class AbsoluteZero extends WeaponBase:
	var cooldown := 1.6
	func _init() -> void:
		weapon_id = "fus_abszero"
		display_name = "Absolute Zero"
	func _physics_process(delta: float) -> void:
		if player == null or player.downed:
			return
		cooldown -= delta
		if cooldown > 0.0:
			return
		var radius := (140.0 + 28.0 * (level - 1)) * player.area_mult
		var dmg := 3.0 * player.damage_mult * (1.0 + 0.5 * (level - 1))
		var any := false
		for e in get_tree().get_nodes_in_group("enemies"):
			if global_position.distance_to(e.global_position) <= radius + e.radius:
				e.take_hit(dmg, global_position, Enemy.DMG_ICE)
				e.apply_slow(0.3, 2.0 * player.duration_mult)
				any = true
		if not any:
			cooldown = 0.25
			return
		var fx := RingFx.new()
		fx.position = global_position
		fx.radius = 25.0
		fx.max_radius = radius
		fx.life = 0.4
		fx.color = Color(0.6, 0.9, 1.0)
		player.get_parent().add_child(fx)
		Sfx.play("frost", global_position)
		cooldown = 3.0 * player.rate_mult


# --- flame + frost: burn + freeze cone ---------------------------------------
class ThermalShock extends WeaponBase:
	const TICK := 0.15
	const HALF := 0.6
	var tick := 0.0
	func _init() -> void:
		weapon_id = "fus_thermal"
		display_name = "Thermal Shock"
	func _physics_process(delta: float) -> void:
		queue_redraw()
		if player == null or player.downed:
			return
		tick -= delta
		if tick > 0.0:
			return
		tick = TICK * player.rate_mult
		var reach := (150.0 + 12.0 * (level - 1)) * player.area_mult
		var dmg := 0.8 * player.damage_mult * (1.0 + 0.4 * (level - 1))
		var any := false
		for e in get_tree().get_nodes_in_group("enemies"):
			var to: Vector2 = e.global_position - player.global_position
			if to.length() <= reach + e.radius and absf(player.facing.angle_to(to)) <= HALF:
				e.take_hit(dmg, null, Enemy.DMG_FIRE)
				ignite(e, dmg)
				e.apply_slow(0.6, 0.8 * player.duration_mult)
				any = true
		if any:
			Sfx.play("flame", player.global_position)
	func _draw() -> void:
		if player == null or player.downed:
			return
		var reach := (150.0 + 12.0 * (level - 1)) * player.area_mult
		var base_a := player.facing.angle()
		for i in 7:
			var ang := base_a + randf_range(-HALF * 0.8, HALF * 0.8)
			var dist := randf_range(reach * 0.25, reach)
			var col := Color(1.0, 0.5, 0.2) if randf() < 0.5 else Color(0.5, 0.85, 1.0)
			draw_circle(Vector2.from_angle(ang) * dist, randf_range(4.0, 10.0),
				Color(col.r, col.g, col.b, randf_range(0.3, 0.6)))


# --- gravity + orbit: hold enemies in a blade ring ---------------------------
class EventHorizon extends WeaponBase:
	const ORBIT_R := 88.0
	const BLADE_R := 12.0
	const HIT_CD := 0.4
	var angle := 0.0
	var hit_cd := {}
	func _init() -> void:
		weapon_id = "fus_eventhorizon"
		display_name = "Event Horizon"
	func _physics_process(delta: float) -> void:
		if player == null or player.downed:
			queue_redraw()
			return
		angle = fmod(angle + 3.2 / player.rate_mult * delta, TAU)
		queue_redraw()
		var orbit_r := ORBIT_R * player.area_mult
		var pull_r := orbit_r * 2.4
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.pull_immune:
				continue
			var off: Vector2 = e.global_position - global_position
			if off.length() <= pull_r:
				var ring_point: Vector2 = global_position + off.normalized() * orbit_r
				e.global_position = e.global_position.move_toward(ring_point, 90.0 * delta)
		var expired := []
		for k in hit_cd:
			hit_cd[k] -= delta
			if hit_cd[k] <= 0.0:
				expired.append(k)
		for k in expired:
			hit_cd.erase(k)
		var n := 2 + level
		var blade_r := BLADE_R * player.area_mult
		var dmg := 2.2 * player.damage_mult * (1.0 + 0.4 * (level - 1))
		for e in get_tree().get_nodes_in_group("enemies"):
			if hit_cd.has(e.get_instance_id()):
				continue
			for i in n:
				var bp: Vector2 = global_position + Vector2.from_angle(angle + TAU * float(i) / n) * orbit_r
				if bp.distance_to(e.global_position) <= blade_r + e.radius:
					e.take_hit(dmg, bp, Enemy.DMG_ENERGY)
					hit_cd[e.get_instance_id()] = HIT_CD * player.rate_mult
					break
	func _draw() -> void:
		if player == null or player.downed:
			return
		var orbit_r := ORBIT_R * player.area_mult
		var blade_r := BLADE_R * player.area_mult
		draw_arc(Vector2.ZERO, orbit_r, 0.0, TAU, 40, Color(0.6, 0.4, 0.9, 0.25), 2.0)
		var n := 2 + level
		for i in n:
			var p := Vector2.from_angle(angle + TAU * float(i) / n) * orbit_r
			draw_circle(p, blade_r, Color(0.8, 0.6, 1.0))
			draw_circle(p, blade_r * 0.5, Color(0.4, 0.25, 0.6))


# --- glaive + gravity: glaives + a vortex on the target ----------------------
class VortexBlade extends WeaponBase:
	var cooldown := 1.0
	func _init() -> void:
		weapon_id = "fus_vortexblade"
		display_name = "Vortex Blade"
	func _physics_process(delta: float) -> void:
		if player == null or player.downed:
			return
		cooldown -= delta
		if cooldown > 0.0:
			return
		var target := player.nearest_enemy(650.0)
		if target == null:
			cooldown = 0.1
			return
		var base := (target.global_position - player.global_position).normalized()
		var count := 2 + level
		for i in count:
			var g := GlaiveProj.new()
			g.player = player
			g.velocity = base.rotated(deg_to_rad(22.0) * (i - (count - 1) / 2.0)) * 430.0
			g.damage = 2.6 * player.damage_mult * (1.0 + 0.3 * (level - 1))
			g.hit_radius = 14.0 * player.area_mult
			g.position = player.global_position
			player.get_parent().add_child(g)
		var w := GravityWell.new()
		w.radius = (120.0 + 12.0 * (level - 1)) * player.area_mult
		w.damage = 0.8 * player.damage_mult * (1.0 + 0.4 * (level - 1))
		w.pull = 150.0
		w.life = 2.0 * player.duration_mult
		w.position = target.global_position
		player.get_parent().add_child(w)
		Sfx.play("glaive", player.global_position)
		cooldown = 1.8 * player.rate_mult


# --- lightning + nova: a blast that forks lightning --------------------------
class Thunderclap extends WeaponBase:
	var cooldown := 1.4
	func _init() -> void:
		weapon_id = "fus_thunderclap"
		display_name = "Thunderclap"
	func _physics_process(delta: float) -> void:
		if player == null or player.downed:
			return
		cooldown -= delta
		if cooldown > 0.0:
			return
		var radius := (130.0 + 25.0 * (level - 1)) * player.area_mult
		var dmg := 3.0 * player.damage_mult * (1.0 + 0.4 * (level - 1))
		var hits: Array = []
		for e in get_tree().get_nodes_in_group("enemies"):
			if global_position.distance_to(e.global_position) <= radius + e.radius:
				e.take_hit(dmg, global_position, Enemy.DMG_ENERGY)
				hits.append(e)
		if hits.is_empty():
			cooldown = 0.25
			return
		var fx := RingFx.new()
		fx.position = global_position
		fx.radius = 25.0
		fx.max_radius = radius
		fx.life = 0.35
		fx.color = Color(0.8, 0.85, 1.0)
		player.get_parent().add_child(fx)
		hits.shuffle()
		for h in hits.slice(0, 3 + level):
			var nb := _nearest_beyond(h.global_position, radius * 1.6)
			if nb != null:
				nb.take_hit(dmg * 0.6, null, Enemy.DMG_ENERGY)
				var lf := LightningFx.new()
				lf.points = [h.global_position, nb.global_position]
				player.get_parent().add_child(lf)
		Sfx.play("lightning", global_position)
		cooldown = 2.8 * player.rate_mult
	func _nearest_beyond(from: Vector2, rng: float) -> Node2D:
		var best: Node2D = null
		var bd := rng * rng
		for e in get_tree().get_nodes_in_group("enemies"):
			if from.distance_to(e.global_position) < 12.0:
				continue
			var d: float = from.distance_squared_to(e.global_position)
			if d < bd:
				bd = d
				best = e
		return best


# --- mines + orbit: orbiting blades that fling mines -------------------------
class MineHalo extends WeaponBase:
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
		angle = fmod(angle + 3.0 / player.rate_mult * delta, TAU)
		queue_redraw()
		var expired := []
		for k in hit_cd:
			hit_cd[k] -= delta
			if hit_cd[k] <= 0.0:
				expired.append(k)
		for k in expired:
			hit_cd.erase(k)
		var n := 2 + level
		var orbit_r := ORBIT_R * player.area_mult
		var blade_r := BLADE_R * player.area_mult
		var dmg := 2.0 * player.damage_mult * (1.0 + 0.4 * (level - 1))
		for e in get_tree().get_nodes_in_group("enemies"):
			if hit_cd.has(e.get_instance_id()):
				continue
			for i in n:
				var bp: Vector2 = global_position + Vector2.from_angle(angle + TAU * float(i) / n) * orbit_r
				if bp.distance_to(e.global_position) <= blade_r + e.radius:
					e.take_hit(dmg, bp)
					hit_cd[e.get_instance_id()] = HIT_CD * player.rate_mult
					break
		drop_cd -= delta
		if drop_cd <= 0.0 and get_tree().get_nodes_in_group("mines").size() < 4 + level:
			var bp := global_position + Vector2.from_angle(angle) * orbit_r * 1.4
			var m := MineNode.new()
			m.damage = 5.0 * player.damage_mult * (1.0 + 0.4 * (level - 1))
			m.blast_radius = 90.0 * player.area_mult
			m.trigger_radius = 50.0 * player.area_mult
			m.life = 10.0 * player.duration_mult
			m.position = bp
			player.get_parent().add_child(m)
			Sfx.play("mine", bp)
			drop_cd = 1.3 * player.rate_mult
	func _draw() -> void:
		if player == null or player.downed:
			return
		var n := 2 + level
		var orbit_r := ORBIT_R * player.area_mult
		var blade_r := BLADE_R * player.area_mult
		for i in n:
			var p := Vector2.from_angle(angle + TAU * float(i) / n) * orbit_r
			draw_circle(p, blade_r, Color(0.8, 0.7, 0.5))
			draw_circle(p, blade_r * 0.45, Color(1.0, 0.3, 0.2))
