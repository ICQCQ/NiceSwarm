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
	"orbit|venom": {"name": "Toxic Halo", "desc": "orbiting blades that poison on contact and paint a rotating ring of toxic ground"},
	"nova|orbit": {"name": "Pulsar", "desc": "orbiting blades that each breathe, pulsing their own mini-nova as they spin"},
	"bolt|frost": {"name": "Frost Lance", "desc": "a piercing volley of chilling lances that shatter already-frozen foes"},
	"lightning|venom": {"name": "Plague Arc", "desc": "a chain that poisons every link"},
	"lightning|orbit": {"name": "Tesla Halo", "desc": "orbiting blades that zap nearby foes"},
	"flame|lightning": {"name": "Plasma Storm", "desc": "a searing cone that crackles with chained bolts"},
	"glaive|nova": {"name": "Cyclone", "desc": "whirling glaives around a pulsing core"},
	"missiles|turret": {"name": "Missile Battery", "desc": "a deployed launcher firing homing salvos"},
	"laser|turret": {"name": "Beam Sentry", "desc": "a deployed turret that sweeps a beam"},
	"frost|turret": {"name": "Cryo Sentry", "desc": "a deployed turret firing slowing shots"},
	"laser|nova": {"name": "Nova Beam", "desc": "sweeping beams that pulse a nova"},
	"bolt|missiles": {"name": "Flak Battery", "desc": "rapid homing flak shells that curve toward foes and burst into shrapnel"},
	"nova|venom": {"name": "Toxic Nova", "desc": "a blast that leaves a poison pool"},
	"bolt|turret": {"name": "Gatling Nest", "desc": "a swarm of short-lived, rapid-redeploy mini-turrets carpeting the field"},
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
	"glaive|gravity": {"name": "Vortex Blade", "desc": "glaives that drop a small pulling vortex on every hit"},
	"lightning|nova": {"name": "Thunderclap", "desc": "a blast that forks lightning out of every hit"},
	"mines|orbit": {"name": "Mine Halo", "desc": "orbiting blades that fling proximity mines"},
	"bolt|flame": {"name": "Incendiary Rounds", "desc": "bolts that ignite the ground on impact, leaving a burning field"},
	"bolt|orbit": {"name": "Scatter Shot", "desc": "a ring of bolts fired in all directions"},
	"bolt|glaive": {"name": "Ricochet", "desc": "bolts that arc to the next enemy on every hit"},
	"bolt|gravity": {"name": "Gravity Round", "desc": "bolts that form a gravity vortex on impact"},
	"bolt|laser": {"name": "Chaingun", "desc": "a blazing rapid-fire bolt stream"},
	"bolt|mines": {"name": "Sapper Round", "desc": "bolts that arm a proximity mine on impact"},
	"bolt|venom": {"name": "Corrosive Round", "desc": "bolts that shatter into a corrosive splash on hit"},
	"frost|laser": {"name": "Cryo Beam", "desc": "rotating ice beams that chill everything they sweep"},
	"frost|mines": {"name": "Glacial Mine", "desc": "mines that detonate into a freezing blast"},
	"frost|missiles": {"name": "Cryo Missile", "desc": "homing missiles that slow all targets in the blast"},
	"frost|venom": {"name": "Frostbite", "desc": "a pool that chills and poisons everything inside"},
	"flame|gravity": {"name": "Cinder Vortex", "desc": "a vortex that drags enemies into a burning pool"},
	"gravity|laser": {"name": "Accretion Beam", "desc": "a vortex ringed by rotating energy beams"},
	"gravity|lightning": {"name": "Storm Vortex", "desc": "a vortex that arcs lightning between everything it traps"},
	"gravity|mines": {"name": "Implosion Mine", "desc": "a vortex that seeds mines around its collapsing core"},
	"gravity|missiles": {"name": "Implosion Salvo", "desc": "a vortex that launches a salvo of homing missiles"},
	"glaive|mines": {"name": "Shrapnel Mine", "desc": "mines that burst into a spray of glaive shrapnel"},
	"laser|mines": {"name": "Beam Mine", "desc": "mines that pulse laser spokes outward on blast"},
	"lightning|mines": {"name": "Tesla Mine", "desc": "mines that chain lightning outward from the blast"},
	"mines|nova": {"name": "Nova Mine", "desc": "mines that pulse a second energy blast on detonation"},
	"mines|venom": {"name": "Toxic Mine", "desc": "mines that leave a toxic pool on blast"},
	"flame|glaive": {"name": "Inferno Blade", "desc": "boomerangs that ignite foes and leave fire pools where they strike"},
	"flame|laser": {"name": "Solar Lance", "desc": "a continuous beam of searing light"},
	"flame|missiles": {"name": "Phoenix Rocket", "desc": "homing rockets that leave a burning crater on impact"},
	"flame|orbit": {"name": "Blaze Halo", "desc": "orbiting blades that ignite on contact and pulse a ring of fire"},
	"glaive|laser": {"name": "Photon Disc", "desc": "boomerangs that fire a piercing beam from every hit"},
	"glaive|missiles": {"name": "Rotor Missile", "desc": "homing rockets that burst into glaive shrapnel"},
	"glaive|orbit": {"name": "Blade Tempest", "desc": "a ring of blades where one periodically breaks off, strikes as a glaive, and rejoins the ring"},
	"glaive|venom": {"name": "Plague Blade", "desc": "boomerangs that poison foes and leave toxic pools where they strike"},
	"laser|lightning": {"name": "Ion Storm", "desc": "rotating beams that arc lightning to nearby foes"},
	"laser|missiles": {"name": "Beam Battery", "desc": "rotating beams backed by homing rocket fire"},
	"laser|venom": {"name": "Acid Ray", "desc": "rotating beams that corrode foes and seed toxic pools"},
	"lightning|missiles": {"name": "EMP Missile", "desc": "homing rockets that chain lightning on impact"},
	"missiles|orbit": {"name": "Rocket Halo", "desc": "orbiting blades tag whatever they strike for a homing missile to finish"},
	"missiles|venom": {"name": "Plague Rocket", "desc": "homing rockets that burst into a toxic cloud"},
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
		"bolt|flame": return IncendiaryRounds.new()
		"bolt|orbit": return ScatterShot.new()
		"bolt|glaive": return Ricochet.new()
		"bolt|gravity": return GravityRound.new()
		"bolt|laser": return Chaingun.new()
		"bolt|mines": return SapperRound.new()
		"bolt|venom": return CorrosiveRound.new()
		"frost|laser": return CryoBeam.new()
		"frost|mines": return GlacialMine.new()
		"frost|missiles": return CryoMissile.new()
		"frost|venom": return Frostbite.new()
		"flame|gravity": return CinderVortex.new()
		"gravity|laser": return AccretionBeam.new()
		"gravity|lightning": return StormVortex.new()
		"gravity|mines": return ImplosionMine.new()
		"gravity|missiles": return ImplosionSalvo.new()
		"glaive|mines": return ShrapnelMine.new()
		"laser|mines": return BeamMine.new()
		"lightning|mines": return TeslaMine.new()
		"mines|nova": return NovaMine.new()
		"mines|venom": return ToxicMine.new()
		"flame|glaive": return InfernoBlade.new()
		"flame|laser": return SolarLance.new()
		"flame|missiles": return PhoenixRocket.new()
		"flame|orbit": return BlazeHalo.new()
		"glaive|laser": return PhotonDisc.new()
		"glaive|missiles": return RotorMissile.new()
		"glaive|orbit": return BladeTempest.new()
		"glaive|venom": return PlagueBlade.new()
		"laser|lightning": return IonStorm.new()
		"laser|missiles": return BeamBattery.new()
		"laser|venom": return AcidRay.new()
		"lightning|missiles": return EMPMissile.new()
		"missiles|orbit": return RocketHalo.new()
		"missiles|venom": return PlagueRocket.new()
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
			p.source_pid = player.peer_id
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
			cur.take_hit(dmg, null, Enemy.DMG_PHYS, player.peer_id)
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
		for e in Main.instance.all_enemies():
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
		p.source_pid = player.peer_id
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
		w.source_pid = player.peer_id
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
		m.source_pid = player.peer_id
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
		for e in Main.instance.all_enemies():
			if hit_cd.has(e.get_instance_id()):
				continue
			var rel: Vector2 = e.global_position - global_position
			for s in spokes:
				var dir := Vector2.from_angle(angle + TAU * float(s) / spokes)
				var along := clampf(rel.dot(dir), 0.0, length)
				if (dir * along).distance_to(rel) <= 7.0 + e.radius:
					e.take_hit(dmg, global_position + dir * along, Enemy.DMG_PHYS, player.peer_id)
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
		var dmg := 2.8 * player.damage_mult * (1.0 + 0.3 * (level - 1))
		for i in count:
			var g := GlaiveProj.new()
			g.source_pid = player.peer_id
			g.player = player
			g.velocity = base.rotated(deg_to_rad(22.0) * (i - (count - 1) / 2.0)) * 430.0
			g.damage = 0.0
			g.burn_dps = dmg * 0.3
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
		for e in Main.instance.all_enemies():
			var rel: Vector2 = e.global_position - origin
			var along := rel.dot(dir)
			if along >= 0.0 and along <= length and (dir * along).distance_to(rel) <= width + e.radius:
				e.take_hit(dmg, origin, Enemy.DMG_PHYS, player.peer_id)
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
		for e in Main.instance.all_enemies():
			if global_position.distance_to(e.global_position) <= radius + e.radius:
				e.take_hit(dmg, global_position, Enemy.DMG_PHYS, player.peer_id)
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
		pud.source_pid = player.peer_id
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
		for e in Main.instance.all_enemies():
			if hit_cd.has(e.get_instance_id()):
				continue
			for i in n:
				var bp: Vector2 = global_position + Vector2.from_angle(angle + TAU * float(i) / n) * orbit_r
				if bp.distance_to(e.global_position) <= blade_r + e.radius:
					e.take_hit(dmg, bp, Enemy.DMG_PHYS, player.peer_id)
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
		w.source_pid = player.peer_id
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
			g.source_pid = player.peer_id
			g.player = player
			g.velocity = base.rotated(deg_to_rad(24.0) * (i - (count - 1) / 2.0)) * 430.0
			g.damage = 0.0
			g.burn_dps = dmg * 0.3
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
		m.source_pid = player.peer_id
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
			m.source_pid = player.peer_id
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
		w.source_pid = player.peer_id
		w.radius = r
		w.damage = 0.8 * dmg
		w.pull = 160.0
		w.life = life
		w.position = target.global_position
		player.get_parent().add_child(w)
		var pud := VenomPuddle.new()
		pud.source_pid = player.peer_id
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
	var trail_cd := 0.0
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
		for e in Main.instance.all_enemies():
			if hit_cd.has(e.get_instance_id()):
				continue
			for i in n:
				var bp: Vector2 = global_position + Vector2.from_angle(angle + TAU * float(i) / n) * orbit_r
				if bp.distance_to(e.global_position) <= blade_r + e.radius:
					e.take_hit(dmg, bp, Enemy.DMG_PHYS, player.peer_id)
					e.apply_burn(dmg * 0.35, 1.5 * player.duration_mult)  # poison
					hit_cd[e.get_instance_id()] = HIT_CD * player.rate_mult
					break
		# every blade continuously paints a toxic ring along its orbit path
		trail_cd -= delta
		if trail_cd <= 0.0:
			trail_cd = (0.16 / n) * player.rate_mult
			var pud := VenomPuddle.new()
			pud.source_pid = player.peer_id
			pud.radius = (16.0 + 2.0 * (level - 1)) * player.area_mult
			pud.damage = 0.5 * player.damage_mult * (1.0 + 0.3 * (level - 1))
			pud.max_life = 1.4 * player.duration_mult
			pud.life = pud.max_life
			pud.position = global_position + Vector2.from_angle(angle) * orbit_r
			player.get_parent().add_child(pud)
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
		while pulse_timers.size() < n:
			pulse_timers.append(randf() * PULSE_CD)
		while pulse_timers.size() > n:
			pulse_timers.pop_back()
		var orbit_r := ORBIT_R * player.area_mult
		var blade_r := BLADE_R * player.area_mult
		var dmg := 1.6 * player.damage_mult * (1.0 + 0.4 * (level - 1))
		var pulse_radius := (55.0 + 14.0 * (level - 1)) * player.area_mult
		var pulse_dmg := 2.2 * player.damage_mult * (1.0 + 0.4 * (level - 1))
		for i in n:
			var bp: Vector2 = global_position + Vector2.from_angle(angle + TAU * float(i) / n) * orbit_r
			# contact damage from the spinning blade itself
			for e in get_tree().get_nodes_in_group("enemies"):
				if not hit_cd.has(e.get_instance_id()) and bp.distance_to(e.global_position) <= blade_r + e.radius:
					e.take_hit(dmg, bp, Enemy.DMG_PHYS, player.peer_id)
					hit_cd[e.get_instance_id()] = HIT_CD * player.rate_mult
			# each blade "breathes": independently pulses a small nova at its own position
			pulse_timers[i] -= delta
			if pulse_timers[i] <= 0.0:
				pulse_timers[i] = PULSE_CD * player.rate_mult
				var any := false
				for e in get_tree().get_nodes_in_group("enemies"):
					if bp.distance_to(e.global_position) <= pulse_radius + e.radius:
						e.take_hit(pulse_dmg, bp, Enemy.DMG_ENERGY, player.peer_id)
						ignite(e, pulse_dmg)
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
		var n := 2 + level
		var orbit_r := ORBIT_R * player.area_mult
		var blade_r := BLADE_R * player.area_mult
		for i in n:
			var p := Vector2.from_angle(angle + TAU * float(i) / n) * orbit_r
			var glow := 1.0
			if i < pulse_timers.size():
				glow += 0.8 * clampf(1.0 - pulse_timers[i] / PULSE_CD, 0.0, 1.0)
			draw_circle(p, blade_r * glow, Color(0.7, 0.7, 1.0, 0.55))
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
		var shatter_dmg := 3.0 * player.damage_mult * (1.0 + 0.4 * (level - 1))
		var shatter_radius := (60.0 + 12.0 * (level - 1)) * player.area_mult
		for i in count:
			var s := FrostShard.new()
			s.source_pid = player.peer_id
			s.velocity = base.rotated(deg_to_rad(6.0 * (i - (count - 1) / 2.0))) * 620.0
			s.damage = 2.2 * player.damage_mult * (1.0 + 0.3 * (level - 1))
			s.hit_radius = 8.0 * player.area_mult
			s.life = 1.6 * player.duration_mult
			s.slow_dur = 1.4 * player.duration_mult
			s.pierce_left = 4
			s.shatter_dmg = shatter_dmg  # lances that strike an already-frozen foe shatter it
			s.shatter_radius = shatter_radius
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
			cur.take_hit(dmg, null, Enemy.DMG_ENERGY, player.peer_id)
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
		for e in Main.instance.all_enemies():
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
		for e in Main.instance.all_enemies():
			if hit_cd.has(e.get_instance_id()):
				continue
			for i in n:
				var bp: Vector2 = global_position + Vector2.from_angle(angle + TAU * float(i) / n) * orbit_r
				if bp.distance_to(e.global_position) <= blade_r + e.radius:
					e.take_hit(dmg, bp, Enemy.DMG_ENERGY, player.peer_id)
					ignite(e, dmg)
					hit_cd[e.get_instance_id()] = HIT_CD * player.rate_mult
					_zap(e, dmg)
					break
	func _zap(src: Node2D, dmg: float) -> void:
		var best: Node2D = null
		var bd := 170.0 * 170.0
		for e in Main.instance.all_enemies():
			if e == src:
				continue
			var d: float = src.global_position.distance_squared_to(e.global_position)
			if d < bd:
				bd = d
				best = e
		if best == null:
			return
		best.take_hit(dmg * 0.7, src.global_position, Enemy.DMG_ENERGY, player.peer_id)
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
			for e in Main.instance.all_enemies():
				var to: Vector2 = e.global_position - player.global_position
				if to.length() <= reach + e.radius and absf(player.facing.angle_to(to)) <= HALF:
					e.take_hit(dmg, null, Enemy.DMG_FIRE, player.peer_id)
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
					cur.take_hit(bdmg, null, Enemy.DMG_ENERGY, player.peer_id)
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
		for e in Main.instance.all_enemies():
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
					g.source_pid = player.peer_id
					g.player = player
					g.velocity = base.rotated(TAU * float(i) / count) * 380.0
					g.damage = 0.0
					g.hit_radius = 14.0 * player.area_mult
					g.on_hit = Callable(self, "_on_glaive_hit")
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
			for e in Main.instance.all_enemies():
				if player.global_position.distance_to(e.global_position) <= radius + e.radius:
					e.take_hit(ndmg, player.global_position, Enemy.DMG_ENERGY, player.peer_id)
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

	## Each glaive hit triggers a small energy burst at the hit point instead
	## of dealing direct damage.
	func _on_glaive_hit(_e: Node2D, pos: Vector2) -> void:
		var radius := 50.0 * player.area_mult
		var dmg := 1.0 * player.damage_mult * (1.0 + 0.3 * (level - 1))
		for en in EnemyGrid.near(pos, radius):
			if pos.distance_to(en.global_position) <= radius + en.radius:
				en.take_hit(dmg, pos, Enemy.DMG_ENERGY, player.peer_id)
				ignite(en, dmg)
		var fx := RingFx.new()
		fx.position = pos
		fx.radius = 8.0
		fx.max_radius = radius
		fx.life = 0.25
		fx.color = Color(0.7, 0.9, 1.0)
		player.get_parent().add_child(fx)


# --- deployed turret variants (turret + X) -----------------------------------
class _Sentry extends WeaponBase:
	var cooldown := 1.5
	var mode := "bolt"
	var dmg_base := WeaponConfig.BASE.sentry.dmg
	var life_scale := 1.0      # fused Gatling Nest: shorter-lived, faster-redeploying turrets
	var cooldown_scale := 1.0
	func _deploy_cap() -> int:
		return level + 2
	func _physics_process(delta: float) -> void:
		if player == null or player.downed:
			return
		cooldown -= delta
		if cooldown > 0.0:
			return
		var mine := 0
		for tn in get_tree().get_nodes_in_group("turrets"):
			if tn.owner_weapon_id == get_instance_id():
				mine += 1
		if mine >= _deploy_cap():
			cooldown = 0.3
			return
		var t := TurretNode.new()
		t.owner_weapon_id = get_instance_id()
		t.source_pid = player.peer_id
		t.mode = mode
		t.life = (6.0 + 0.5 * level) * player.duration_mult * life_scale
		t.damage = dmg_base * player.damage_mult * (1.0 + WeaponConfig.BASE.sentry.growth * (level - 1))
		t.target_range = 480.0 * player.area_mult
		t.proj_radius = 5.0 * player.area_mult
		t.area_mult = player.area_mult
		t.dur_mult = player.duration_mult
		t.fire_mult = player.rate_mult
		t.position = player.global_position
		player.get_parent().add_child(t)
		Sfx.play("turret_deploy", player.global_position)
		cooldown = WeaponConfig.BASE.sentry.cd * player.rate_mult * cooldown_scale

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
		for e in Main.instance.all_enemies():
			if hit_cd.has(e.get_instance_id()):
				continue
			var rel: Vector2 = e.global_position - global_position
			for b in beams:
				var dir := Vector2.from_angle(angle + TAU * float(b) / beams)
				var along := clampf(rel.dot(dir), 0.0, length)
				if (dir * along).distance_to(rel) <= 6.0 + e.radius:
					e.take_hit(dmg, global_position + dir * along, Enemy.DMG_ENERGY, player.peer_id)
					ignite(e, dmg)
					hit_cd[e.get_instance_id()] = HIT_CD * player.rate_mult
					break
		nova_cd -= delta
		if nova_cd <= 0.0:
			var radius := (110.0 + 22.0 * (level - 1)) * player.area_mult
			var ndmg := 2.5 * player.damage_mult * (1.0 + 0.4 * (level - 1))
			var any := false
			for e in Main.instance.all_enemies():
				if global_position.distance_to(e.global_position) <= radius + e.radius:
					e.take_hit(ndmg, global_position, Enemy.DMG_ENERGY, player.peer_id)
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
	func _init() -> void:
		weapon_id = "fus_barrage"
		display_name = "Flak Battery"
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
		var count := 1 + level
		var dmg := 1.0 * player.damage_mult * (1.0 + 0.3 * (level - 1))
		var splash := (36.0 + 6.0 * (level - 1)) * player.area_mult
		for i in count:
			var p := Projectile.new()
			p.source_pid = player.peer_id
			p.velocity = base.rotated(deg_to_rad(14.0) * (i - (count - 1) / 2.0)) * 480.0
			p.damage = dmg * 0.4
			p.radius = 4.0 * player.area_mult
			p.life = 1.8 * player.duration_mult
			p.explode_radius = splash  # every shot is a self-propelled flak shell
			p.explode_damage = dmg
			p.homing_turn = 5.0  # curves toward the nearest enemy as it flies
			p.homing_range = 260.0 * player.area_mult
			p.color = Color(1.0, 0.7, 0.3)
			p.position = player.global_position
			player.get_parent().add_child(p)
		Sfx.play("missile", player.global_position, -6.0)
		cooldown = 0.5 * player.rate_mult


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
		for e in Main.instance.all_enemies():
			if global_position.distance_to(e.global_position) <= radius + e.radius:
				e.take_hit(dmg, global_position, Enemy.DMG_PHYS, player.peer_id)
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
		pud.source_pid = player.peer_id
		pud.radius = radius * 0.7
		pud.damage = dmg * 0.25
		pud.max_life = 2.5 * player.duration_mult
		pud.life = pud.max_life
		pud.position = global_position
		player.get_parent().add_child(pud)
		Sfx.play("nova", global_position)
		cooldown = 3.0 * player.rate_mult


# --- turret + every other weapon: deployed sentry variants --------------------
# bolt + turret: instead of a couple of sustained sentries, throw down a swarm
# of short-lived gatling nests that are constantly being redeployed
class GunTurret extends _Sentry:
	func _init() -> void:
		weapon_id = "fus_gunturret"
		display_name = "Gatling Nest"
		mode = "bolt"
		dmg_base = 1.5
		life_scale = 0.4
		cooldown_scale = 0.3
	func _deploy_cap() -> int:
		return level + 5

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
		for e in Main.instance.all_enemies():
			if global_position.distance_to(e.global_position) <= radius + e.radius:
				e.take_hit(dmg, global_position, Enemy.DMG_ICE, player.peer_id)
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
		for e in Main.instance.all_enemies():
			var to: Vector2 = e.global_position - player.global_position
			if to.length() <= reach + e.radius and absf(player.facing.angle_to(to)) <= HALF:
				e.take_hit(dmg, null, Enemy.DMG_FIRE, player.peer_id)
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
		for e in Main.instance.all_enemies():
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
		for e in Main.instance.all_enemies():
			if hit_cd.has(e.get_instance_id()):
				continue
			for i in n:
				var bp: Vector2 = global_position + Vector2.from_angle(angle + TAU * float(i) / n) * orbit_r
				if bp.distance_to(e.global_position) <= blade_r + e.radius:
					e.take_hit(dmg, bp, Enemy.DMG_ENERGY, player.peer_id)
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
			g.source_pid = player.peer_id
			g.player = player
			g.velocity = base.rotated(deg_to_rad(22.0) * (i - (count - 1) / 2.0)) * 430.0
			g.damage = 0.0
			g.hit_radius = 14.0 * player.area_mult
			g.on_hit = Callable(self, "_on_glaive_hit")
			g.position = player.global_position
			player.get_parent().add_child(g)
		Sfx.play("glaive", player.global_position)
		cooldown = 1.8 * player.rate_mult

	## Each glaive hit drops a small gravity well at the hit point instead of
	## dealing direct damage.
	func _on_glaive_hit(_e: Node2D, pos: Vector2) -> void:
		var w := GravityWell.new()
		w.source_pid = player.peer_id
		w.radius = (50.0 + 6.0 * (level - 1)) * player.area_mult
		w.damage = 0.35 * player.damage_mult * (1.0 + 0.3 * (level - 1))
		w.pull = 120.0
		w.life = 1.0 * player.duration_mult
		w.position = pos
		player.get_parent().add_child(w)


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
		for e in Main.instance.all_enemies():
			if global_position.distance_to(e.global_position) <= radius + e.radius:
				e.take_hit(dmg, global_position, Enemy.DMG_ENERGY, player.peer_id)
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
				nb.take_hit(dmg * 0.6, null, Enemy.DMG_ENERGY, player.peer_id)
				var lf := LightningFx.new()
				lf.points = [h.global_position, nb.global_position]
				player.get_parent().add_child(lf)
		Sfx.play("lightning", global_position)
		cooldown = 2.8 * player.rate_mult
	func _nearest_beyond(from: Vector2, rng: float) -> Node2D:
		var best: Node2D = null
		var bd := rng * rng
		for e in Main.instance.all_enemies():
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
		for e in Main.instance.all_enemies():
			if hit_cd.has(e.get_instance_id()):
				continue
			for i in n:
				var bp: Vector2 = global_position + Vector2.from_angle(angle + TAU * float(i) / n) * orbit_r
				if bp.distance_to(e.global_position) <= blade_r + e.radius:
					e.take_hit(dmg, bp, Enemy.DMG_PHYS, player.peer_id)
					hit_cd[e.get_instance_id()] = HIT_CD * player.rate_mult
					break
		drop_cd -= delta
		if drop_cd <= 0.0 and get_tree().get_nodes_in_group("mines").size() < 4 + level:
			var bp := global_position + Vector2.from_angle(angle) * orbit_r * 1.4
			var m := MineNode.new()
			m.source_pid = player.peer_id
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


# --- bolt + flame: bolts that drop a burning puddle on impact ----------------
class IncendiaryRounds extends WeaponBase:
	var cooldown := 0.45
	func _init() -> void:
		weapon_id = "fus_incendiary"
		display_name = "Incendiary Rounds"
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
		var base_dir := (target.global_position - player.global_position).normalized()
		var count := 1 + level
		var dmg := 1.8 * player.damage_mult * (1.0 + 0.35 * (level - 1))
		var puddle_r := (50.0 + 8.0 * (level - 1)) * player.area_mult
		var puddle_life := 2.5 * player.duration_mult
		for i in count:
			var spread := deg_to_rad(9.0) * (i - (count - 1) / 2.0)
			var p := Projectile.new()
			p.source_pid = player.peer_id
			p.velocity = base_dir.rotated(spread) * 500.0
			p.damage = dmg
			p.radius = 6.0 * player.area_mult
			p.life = 1.6 * player.duration_mult
			p.color = Color(1.0, 0.55, 0.15)
			p.fire_puddle_radius = puddle_r
			p.fire_puddle_damage = 0.6 * player.damage_mult * (1.0 + 0.3 * (level - 1))
			p.fire_puddle_life = puddle_life
			p.fire_puddle_burn_dps = 0.9 * player.damage_mult * (1.0 + 0.3 * (level - 1))
			p.fire_puddle_burn_dur = 1.5 * player.duration_mult
			p.fire_puddle_source_pid = player.peer_id
			p.position = player.global_position
			player.get_parent().add_child(p)
		Sfx.play("bolt", player.global_position)
		cooldown = 0.85 * player.rate_mult


# --- bolt + orbit: ring of bolts in all directions ---------------------------
class ScatterShot extends WeaponBase:
	var cooldown := 1.5
	func _init() -> void:
		weapon_id = "fus_scatter"
		display_name = "Scatter Shot"
	func _physics_process(delta: float) -> void:
		if player == null or player.downed:
			return
		cooldown -= delta
		if cooldown > 0.0:
			return
		var count := 6 + 2 * level  # 8 / 10 / 12 bolts
		var dmg := 1.8 * player.damage_mult * (1.0 + 0.35 * (level - 1))
		for i in count:
			var dir := Vector2.from_angle(TAU * float(i) / count)
			var p := Projectile.new()
			p.source_pid = player.peer_id
			p.velocity = dir * 480.0
			p.damage = dmg
			p.radius = 5.5 * player.area_mult
			p.life = 1.5 * player.duration_mult
			p.color = Color(0.9, 0.8, 0.3)
			p.position = player.global_position
			player.get_parent().add_child(p)
		Sfx.play("bolt", player.global_position)
		cooldown = 2.2 * player.rate_mult


# --- bolt + glaive: bolt chains to next enemy on hit -------------------------
class Ricochet extends WeaponBase:
	var cooldown := 0.6
	func _init() -> void:
		weapon_id = "fus_ricochet"
		display_name = "Ricochet"
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
		var visited := {target.get_instance_id(): true}
		_fire(player.global_position, target, level, visited, 1.0)
		Sfx.play("bolt", player.global_position)
		cooldown = 1.0 * player.rate_mult
	func _fire(from: Vector2, toward: Node2D, hops_left: int, visited: Dictionary, dmg_scale: float) -> void:
		var dir := (toward.global_position - from).normalized()
		var p := Projectile.new()
		p.source_pid = player.peer_id
		p.velocity = dir * 540.0
		p.damage = 2.8 * player.damage_mult * (1.0 + 0.35 * (level - 1)) * dmg_scale
		p.radius = 6.0 * player.area_mult
		p.life = 2.0 * player.duration_mult
		p.color = Color(0.95, 0.8, 0.2)
		if hops_left > 0:
			p.on_hit = Callable(self, "_chain").bind(hops_left, visited.duplicate(), dmg_scale * 0.7)
		p.position = from
		player.get_parent().add_child(p)
	func _chain(enemy: Node2D, hit_pos: Vector2, _world: Node, hops_left: int, visited: Dictionary, dmg_scale: float) -> void:
		if player == null:
			return
		var chain_r := 220.0 * player.area_mult
		var best: Node2D = null
		var bd := chain_r * chain_r
		for e in get_tree().get_nodes_in_group("enemies"):
			if visited.has(e.get_instance_id()):
				continue
			var d := hit_pos.distance_squared_to(e.global_position)
			if d < bd:
				bd = d
				best = e
		if best == null:
			return
		visited[best.get_instance_id()] = true
		_fire(hit_pos, best, hops_left - 1, visited, dmg_scale)
		Sfx.play("bolt", hit_pos, -10.0)


# --- bolt + gravity: bolt spawns a gravity well at impact --------------------
class GravityRound extends WeaponBase:
	var cooldown := 0.9
	func _init() -> void:
		weapon_id = "fus_gravround"
		display_name = "Gravity Round"
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
		var dmg := 2.2 * player.damage_mult * (1.0 + 0.4 * (level - 1))
		for i in level:
			var spread := deg_to_rad(9.0) * (i - (level - 1) / 2.0)
			var p := Projectile.new()
			p.source_pid = player.peer_id
			p.velocity = dir.rotated(spread) * 500.0
			p.damage = dmg
			p.radius = 5.5 * player.area_mult
			p.life = 1.6 * player.duration_mult
			p.color = Color(0.7, 0.5, 1.0)
			p.on_hit = Callable(self, "_spawn_well")
			p.position = player.global_position
			player.get_parent().add_child(p)
		Sfx.play("bolt", player.global_position)
		cooldown = 1.4 * player.rate_mult
	func _spawn_well(_enemy: Node2D, hit_pos: Vector2, world: Node) -> void:
		if player == null:
			return
		var w := GravityWell.new()
		w.source_pid = player.peer_id
		w.radius = (80.0 + 10.0 * (level - 1)) * player.area_mult
		w.damage = 0.5 * player.damage_mult * (1.0 + 0.3 * (level - 1))
		w.pull = 220.0
		w.life = 1.5 * player.duration_mult
		w.position = hit_pos
		world.add_child(w)
		Sfx.play("gravity", hit_pos, -6.0)


# --- bolt + laser: rapid single-bolt stream ----------------------------------
class Chaingun extends WeaponBase:
	var cooldown := 0.2
	func _init() -> void:
		weapon_id = "fus_chaingun"
		display_name = "Chaingun"
	func _physics_process(delta: float) -> void:
		if player == null or player.downed:
			return
		cooldown -= delta
		if cooldown > 0.0:
			return
		var target := player.nearest_enemy(680.0)
		if target == null:
			cooldown = 0.08
			return
		var dir := (target.global_position - player.global_position).normalized()
		dir = dir.rotated(randf_range(-0.07, 0.07))
		var p := Projectile.new()
		p.source_pid = player.peer_id
		p.velocity = dir * 600.0
		p.damage = 0.75 * player.damage_mult * (1.0 + 0.4 * (level - 1))
		p.radius = 4.0 * player.area_mult
		p.life = 1.5 * player.duration_mult
		p.color = Color(0.8, 0.95, 1.0)
		p.position = player.global_position
		player.get_parent().add_child(p)
		Sfx.play("bolt", player.global_position, -7.0)
		cooldown = 0.2 * player.rate_mult


# --- bolt + mines: bolt arms a proximity mine on impact ----------------------
class SapperRound extends WeaponBase:
	var cooldown := 0.5
	func _init() -> void:
		weapon_id = "fus_sapper"
		display_name = "Sapper Round"
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
		var dmg := 1.5 * player.damage_mult * (1.0 + 0.35 * (level - 1))
		for i in level:
			var spread := deg_to_rad(10.0) * (i - (level - 1) / 2.0)
			var p := Projectile.new()
			p.source_pid = player.peer_id
			p.velocity = dir.rotated(spread) * 500.0
			p.damage = dmg
			p.radius = 5.0 * player.area_mult
			p.life = 1.6 * player.duration_mult
			p.color = Color(0.85, 0.75, 0.3)
			p.on_hit = Callable(self, "_arm_mine")
			p.position = player.global_position
			player.get_parent().add_child(p)
		Sfx.play("bolt", player.global_position)
		cooldown = 0.9 * player.rate_mult
	func _arm_mine(_enemy: Node2D, hit_pos: Vector2, world: Node) -> void:
		if player == null:
			return
		var m := MineNode.new()
		m.source_pid = player.peer_id
		m.damage = 5.0 * player.damage_mult * (1.0 + 0.4 * (level - 1))
		m.blast_radius = (90.0 + 12.0 * (level - 1)) * player.area_mult
		m.trigger_radius = 50.0 * player.area_mult
		m.life = 8.0 * player.duration_mult
		m.position = hit_pos
		world.add_child(m)
		Sfx.play("mine", hit_pos, -4.0)


# --- bolt + venom: bolt poisons target + leaves a venom pool -----------------
class CorrosiveRound extends WeaponBase:
	var cooldown := 0.5
	func _init() -> void:
		weapon_id = "fus_corrosive"
		display_name = "Corrosive Round"
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
		var dmg := 1.8 * player.damage_mult * (1.0 + 0.35 * (level - 1))
		for i in level:
			var spread := deg_to_rad(9.0) * (i - (level - 1) / 2.0)
			var p := Projectile.new()
			p.source_pid = player.peer_id
			p.velocity = dir.rotated(spread) * 510.0
			p.damage = dmg
			p.radius = 5.5 * player.area_mult
			p.life = 1.6 * player.duration_mult
			p.color = Color(0.45, 0.9, 0.35)
			p.on_hit = Callable(self, "_corrode")
			p.position = player.global_position
			player.get_parent().add_child(p)
		Sfx.play("bolt", player.global_position)
		cooldown = 0.9 * player.rate_mult
	func _corrode(enemy: Node2D, hit_pos: Vector2, world: Node) -> void:
		if player == null:
			return
		enemy.apply_burn(1.2 * player.damage_mult * (1.0 + 0.3 * (level - 1)), 2.5 * player.duration_mult)
		var pud := VenomPuddle.new()
		pud.source_pid = player.peer_id
		pud.radius = (45.0 + 7.0 * (level - 1)) * player.area_mult
		pud.damage = 0.5 * player.damage_mult * (1.0 + 0.3 * (level - 1))
		pud.max_life = 2.0 * player.duration_mult
		pud.life = pud.max_life
		pud.position = hit_pos
		world.add_child(pud)
		Sfx.play("venom", hit_pos, -6.0)


# --- frost + laser: rotating ice beams that slow on hit ----------------------
class CryoBeam extends WeaponBase:
	const HIT_CD := 0.4
	var angle := 0.0
	var hit_cd := {}
	func _init() -> void:
		weapon_id = "fus_cryobeam"
		display_name = "Cryo Beam"
	func _physics_process(delta: float) -> void:
		if player == null or player.downed:
			queue_redraw()
			return
		angle = fmod(angle + 1.6 / player.rate_mult * delta, TAU)
		queue_redraw()
		var expired := []
		for k in hit_cd:
			hit_cd[k] -= delta
			if hit_cd[k] <= 0.0:
				expired.append(k)
		for k in expired:
			hit_cd.erase(k)
		var beams := 1 + level
		var length := (170.0 + 25.0 * (level - 1)) * player.area_mult
		var dmg := 1.2 * player.damage_mult * (1.0 + 0.4 * (level - 1))
		for e in get_tree().get_nodes_in_group("enemies"):
			if hit_cd.has(e.get_instance_id()):
				continue
			var rel: Vector2 = e.global_position - global_position
			for b in beams:
				var dir := Vector2.from_angle(angle + TAU * float(b) / beams)
				var along := clampf(rel.dot(dir), 0.0, length)
				if (dir * along).distance_to(rel) <= 9.0 + e.radius:
					e.take_hit(dmg, global_position + dir * along, Enemy.DMG_ICE, player.peer_id)
					e.apply_slow(0.5, dmg * 0.4 * player.duration_mult)
					hit_cd[e.get_instance_id()] = HIT_CD * player.rate_mult
					Sfx.play("frost", e.global_position, -5.0)
					break
	func _draw() -> void:
		if player == null or player.downed:
			return
		var beams := 1 + level
		var length := (170.0 + 25.0 * (level - 1)) * player.area_mult
		for b in beams:
			var dir := Vector2.from_angle(angle + TAU * float(b) / beams)
			draw_line(Vector2.ZERO, dir * length, Color(0.5, 0.85, 1.0, 0.22), 12.0)
			draw_line(Vector2.ZERO, dir * length, Color(0.8, 0.95, 1.0), 2.5)
			draw_circle(dir * length, 7.0 * player.area_mult, Color(0.6, 0.9, 1.0))


# --- frost + mines: mines that freeze all enemies in the blast ---------------
class GlacialMine extends WeaponBase:
	var cooldown := 1.2
	func _init() -> void:
		weapon_id = "fus_glacmine"
		display_name = "Glacial Mine"
	func _physics_process(delta: float) -> void:
		if player == null or player.downed:
			return
		cooldown -= delta
		if cooldown > 0.0:
			return
		if get_tree().get_nodes_in_group("mines").size() >= 3 + level:
			cooldown = 0.2
			return
		var dmg := 5.0 * player.damage_mult * (1.0 + 0.4 * (level - 1))
		var m := MineNode.new()
		m.source_pid = player.peer_id
		m.damage = dmg
		m.blast_radius = (100.0 + 15.0 * (level - 1)) * player.area_mult
		m.trigger_radius = 55.0 * player.area_mult
		m.life = 12.0 * player.duration_mult
		m.freeze_slow = 0.5
		m.freeze_dur = dmg * 0.4 * player.duration_mult
		m.position = player.global_position \
			+ Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 30.0))
		player.get_parent().add_child(m)
		Sfx.play("mine", player.global_position)
		cooldown = 2.2 * player.rate_mult


# --- frost + missiles: homing missiles that slow on splash -------------------
class CryoMissile extends WeaponBase:
	var cooldown := 1.2
	func _init() -> void:
		weapon_id = "fus_cryomissile"
		display_name = "Cryo Missile"
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
		var dmg := 2.5 * player.damage_mult * (1.0 + 0.35 * (level - 1))
		for i in count:
			var m := MissileProj.new()
			m.source_pid = player.peer_id
			m.damage = dmg
			m.splash = (80.0 + 12.0 * (level - 1)) * player.area_mult
			m.life = 4.0 * player.duration_mult
			m.velocity = Vector2.from_angle(randf() * TAU) * 280.0
			m.freeze_slow = 0.5
			m.freeze_dur = dmg * 0.35 * player.duration_mult
			m.position = player.global_position
			player.get_parent().add_child(m)
		Sfx.play("missile", player.global_position)
		cooldown = 2.5 * player.rate_mult


# --- frost + venom: a pool that chills and poisons ---------------------------
class Frostbite extends WeaponBase:
	var cooldown := 1.5
	func _init() -> void:
		weapon_id = "fus_frostbite"
		display_name = "Frostbite"
	func _physics_process(delta: float) -> void:
		if player == null or player.downed:
			return
		cooldown -= delta
		if cooldown > 0.0:
			return
		var target := player.nearest_enemy(600.0)
		if target == null:
			cooldown = 0.2
			return
		var dmg := 0.8 * player.damage_mult * (1.0 + 0.35 * (level - 1))
		var pud := VenomPuddle.new()
		pud.source_pid = player.peer_id
		pud.radius = (60.0 + 8.0 * (level - 1)) * player.area_mult
		pud.damage = dmg
		pud.max_life = 3.5 * player.duration_mult
		pud.life = pud.max_life
		pud.icy = true
		pud.freeze_slow = 0.5
		pud.freeze_dur = dmg * 0.4 * player.duration_mult
		pud.position = target.global_position
		player.get_parent().add_child(pud)
		Sfx.play("frost", target.global_position)
		cooldown = 2.8 * player.rate_mult


# --- flame + gravity: a vortex with a burning pool at its core ---------------
class CinderVortex extends WeaponBase:
	var cooldown := 2.8
	func _init() -> void:
		weapon_id = "fus_cindervortex"
		display_name = "Cinder Vortex"
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
		var r := (160.0 + 15.0 * (level - 1)) * player.area_mult
		var life := 2.8 * player.duration_mult
		var dmg := player.damage_mult * (1.0 + 0.5 * (level - 1))
		var w := GravityWell.new()
		w.source_pid = player.peer_id
		w.radius = r
		w.damage = 0.9 * dmg
		w.pull = 180.0
		w.life = life
		w.position = target.global_position
		player.get_parent().add_child(w)
		var pud := VenomPuddle.new()
		pud.source_pid = player.peer_id
		pud.radius = r * 0.85
		pud.damage = 0.6 * dmg
		pud.max_life = life
		pud.life = life
		pud.fiery = true
		pud.burn_dps = 0.7 * dmg
		pud.burn_dur = 1.4 * player.duration_mult
		pud.position = target.global_position
		player.get_parent().add_child(pud)
		Sfx.play("flame", target.global_position)
		cooldown = 5.5 * player.rate_mult


# --- gravity + laser: a vortex ringed by rotating energy beams ---------------
class AccretionBeam extends WeaponBase:
	var cooldown := 3.0
	func _init() -> void:
		weapon_id = "fus_accretion"
		display_name = "Accretion Beam"
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
		var r := (150.0 + 14.0 * (level - 1)) * player.area_mult
		var w := GravityWell.new()
		w.source_pid = player.peer_id
		w.radius = r
		w.damage = 0.7 * player.damage_mult * (1.0 + 0.4 * (level - 1))
		w.pull = 190.0
		w.life = 3.0 * player.duration_mult
		w.beam_spokes = 1 + level
		w.beam_dmg = 1.6 * player.damage_mult * (1.0 + 0.4 * (level - 1))
		w.beam_len = r
		w.beam_spin = 2.0 / player.rate_mult
		w.position = target.global_position
		player.get_parent().add_child(w)
		Sfx.play("laser", target.global_position)
		cooldown = 5.5 * player.rate_mult


# --- gravity + lightning: a vortex that arcs lightning between its captives --
class StormVortex extends WeaponBase:
	var cooldown := 2.6
	func _init() -> void:
		weapon_id = "fus_stormvortex"
		display_name = "Storm Vortex"
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
		var r := (160.0 + 15.0 * (level - 1)) * player.area_mult
		var w := GravityWell.new()
		w.source_pid = player.peer_id
		w.radius = r
		w.damage = 0.7 * player.damage_mult * (1.0 + 0.4 * (level - 1))
		w.pull = 190.0
		w.life = 2.8 * player.duration_mult
		w.chain_dmg = 1.5 * player.damage_mult * (1.0 + 0.4 * (level - 1))
		w.position = target.global_position
		player.get_parent().add_child(w)
		Sfx.play("lightning", target.global_position)
		cooldown = 5.5 * player.rate_mult


# --- gravity + mines: a vortex that seeds mines around its core --------------
class ImplosionMine extends WeaponBase:
	var cooldown := 3.0
	func _init() -> void:
		weapon_id = "fus_implosionmine"
		display_name = "Implosion Mine"
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
		var r := (150.0 + 14.0 * (level - 1)) * player.area_mult
		var w := GravityWell.new()
		w.source_pid = player.peer_id
		w.radius = r
		w.damage = 0.6 * player.damage_mult * (1.0 + 0.4 * (level - 1))
		w.pull = 200.0
		w.life = 2.6 * player.duration_mult
		w.position = target.global_position
		player.get_parent().add_child(w)
		var dmg := 6.0 * player.damage_mult * (1.0 + 0.4 * (level - 1))
		var count := 1 + level
		for i in count:
			var m := MineNode.new()
			m.source_pid = player.peer_id
			m.damage = dmg
			m.blast_radius = (90.0 + 12.0 * (level - 1)) * player.area_mult
			m.trigger_radius = 45.0 * player.area_mult
			m.life = 6.0 * player.duration_mult
			m.arm = 0.2
			m.position = target.global_position + Vector2.from_angle(TAU * float(i) / count) * r * 0.6
			player.get_parent().add_child(m)
		Sfx.play("mine", target.global_position)
		cooldown = 5.5 * player.rate_mult


# --- gravity + missiles: a vortex that launches a homing missile salvo -------
class ImplosionSalvo extends WeaponBase:
	var cooldown := 3.2
	func _init() -> void:
		weapon_id = "fus_implosionsalvo"
		display_name = "Implosion Salvo"
	func _physics_process(delta: float) -> void:
		if player == null or player.downed:
			return
		cooldown -= delta
		if cooldown > 0.0:
			return
		var target := player.nearest_enemy(750.0)
		if target == null:
			cooldown = 0.2
			return
		var r := (160.0 + 15.0 * (level - 1)) * player.area_mult
		var w := GravityWell.new()
		w.source_pid = player.peer_id
		w.radius = r
		w.damage = 0.5 * player.damage_mult * (1.0 + 0.4 * (level - 1))
		w.pull = 210.0
		w.life = 3.0 * player.duration_mult
		w.position = target.global_position
		player.get_parent().add_child(w)
		var dmg := 2.6 * player.damage_mult * (1.0 + 0.35 * (level - 1))
		var count := 1 + level
		for i in count:
			var m := MissileProj.new()
			m.source_pid = player.peer_id
			m.damage = dmg
			m.splash = (70.0 + 10.0 * (level - 1)) * player.area_mult
			m.life = 4.0 * player.duration_mult
			m.velocity = Vector2.from_angle(TAU * float(i) / count) * 280.0
			m.position = player.global_position
			player.get_parent().add_child(m)
		Sfx.play("missile", player.global_position)
		cooldown = 5.8 * player.rate_mult


# --- shared mine-fusion helper: drop a proximity mine with a bonus payload ---
class _MineFusion extends WeaponBase:
	var cooldown := 1.1
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
		m.source_pid = player.peer_id
		m.damage = 6.0 * player.damage_mult * (1.0 + 0.4 * (level - 1))
		m.blast_radius = (95.0 + 12.0 * (level - 1)) * player.area_mult
		m.trigger_radius = 50.0 * player.area_mult
		m.life = 11.0 * player.duration_mult
		_load(m)
		m.position = player.global_position \
			+ Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 30.0))
		player.get_parent().add_child(m)
		Sfx.play("mine", player.global_position)
		cooldown = 1.9 * player.rate_mult
	## Override: add the fused payload. Payload power uses (level + 1), i.e. the
	## component the mine spawns on blast is one level above the mine itself.
	func _load(_m: MineNode) -> void:
		pass


# --- glaive + mines: mines burst into glaive shrapnel on blast --------------
class ShrapnelMine extends _MineFusion:
	func _init() -> void:
		weapon_id = "fus_shrapnelmine"
		display_name = "Shrapnel Mine"
	func _load(m: MineNode) -> void:
		m.shrapnel_count = 3 + level
		m.shrapnel_dmg = 1.6 * player.damage_mult * (1.0 + 0.3 * level)
		m.shrapnel_radius = 12.0 * player.area_mult


# --- laser + mines: mines pulse laser spokes outward on blast ----------------
class BeamMine extends _MineFusion:
	func _init() -> void:
		weapon_id = "fus_beammine"
		display_name = "Beam Mine"
	func _load(m: MineNode) -> void:
		m.beam_spokes = 2 + level
		m.beam_dmg = 1.8 * player.damage_mult * (1.0 + 0.4 * level)
		m.beam_len = (180.0 + 20.0 * level) * player.area_mult
		m.beam_burn_dur = 1.2 * player.duration_mult


# --- lightning + mines: mines chain lightning outward on blast ---------------
class TeslaMine extends _MineFusion:
	func _init() -> void:
		weapon_id = "fus_teslamine"
		display_name = "Tesla Mine"
	func _load(m: MineNode) -> void:
		m.chain_count = 2 + level
		m.chain_dmg = 2.0 * player.damage_mult * (1.0 + 0.4 * level)
		m.chain_range = 220.0 * player.area_mult


# --- mines + nova: mines pulse a second energy blast on detonation -----------
class NovaMine extends _MineFusion:
	func _init() -> void:
		weapon_id = "fus_novamine"
		display_name = "Nova Mine"
	func _load(m: MineNode) -> void:
		m.nova_radius = (160.0 + 22.0 * level) * player.area_mult
		m.nova_dmg = 2.2 * player.damage_mult * (1.0 + 0.4 * level)


# --- mines + venom: mines leave a toxic pool on blast -------------------------
class ToxicMine extends _MineFusion:
	func _init() -> void:
		weapon_id = "fus_toxicmine"
		display_name = "Toxic Mine"
	func _load(m: MineNode) -> void:
		m.venom_radius = (80.0 + 10.0 * level) * player.area_mult
		m.venom_dps = 1.0 * player.damage_mult * (1.0 + 0.4 * level)
		m.venom_dur = 3.0 * player.duration_mult


# --- flame + glaive: boomerangs that ignite and leave fire pools -------------
class InfernoBlade extends WeaponBase:
	var cooldown := 1.0
	func _init() -> void:
		weapon_id = "fus_infernoblade"
		display_name = "Inferno Blade"
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
		var dmg := 2.4 * player.damage_mult * (1.0 + 0.35 * (level - 1))
		for i in count:
			var g := GlaiveProj.new()
			g.source_pid = player.peer_id
			g.player = player
			g.velocity = base.rotated(deg_to_rad(20.0) * (i - (count - 1) / 2.0)) * 430.0
			g.damage = dmg
			g.burn_dps = dmg * 0.35
			g.hit_radius = 14.0 * player.area_mult
			g.on_hit = Callable(self, "_on_hit")
			g.position = player.global_position
			player.get_parent().add_child(g)
		Sfx.play("flame", player.global_position)
		cooldown = 1.4 * player.rate_mult

	## Each glaive hit leaves a small burning pool behind it.
	func _on_hit(_e: Node2D, pos: Vector2) -> void:
		var pud := VenomPuddle.new()
		pud.source_pid = player.peer_id
		pud.radius = (28.0 + 4.0 * (level - 1)) * player.area_mult
		pud.damage = 0.4 * player.damage_mult * (1.0 + 0.3 * (level - 1))
		pud.max_life = 1.5 * player.duration_mult
		pud.life = pud.max_life
		pud.fiery = true
		pud.burn_dps = 0.5 * player.damage_mult
		pud.burn_dur = 1.0 * player.duration_mult
		pud.position = pos
		player.get_parent().add_child(pud)


# --- flame + laser: a continuous searing beam ---------------------------------
class SolarLance extends WeaponBase:
	const TICK := 0.12
	var tick := 0.0
	func _init() -> void:
		weapon_id = "fus_solarlance"
		display_name = "Solar Lance"
	func _physics_process(delta: float) -> void:
		queue_redraw()
		if player == null or player.downed:
			return
		tick -= delta
		if tick > 0.0:
			return
		tick = TICK * player.rate_mult
		var length := (260.0 + 30.0 * (level - 1)) * player.area_mult
		var width := 16.0 * player.area_mult
		var dmg := 1.0 * player.damage_mult * (1.0 + 0.4 * (level - 1))
		var dir := player.facing
		for e in get_tree().get_nodes_in_group("enemies"):
			var rel: Vector2 = e.global_position - global_position
			var along := rel.dot(dir)
			if along >= 0.0 and along <= length and (dir * along).distance_to(rel) <= width + e.radius:
				e.take_hit(dmg, global_position, Enemy.DMG_FIRE, player.peer_id)
				e.apply_burn(dmg * 0.6, 1.2 * player.duration_mult)
		Sfx.play("laser", global_position, -10.0)
	func _draw() -> void:
		if player == null or player.downed:
			return
		var length := (260.0 + 30.0 * (level - 1)) * player.area_mult
		var dir := player.facing
		draw_line(Vector2.ZERO, dir * length, Color(1.0, 0.5, 0.1, 0.35), 16.0 * player.area_mult)
		draw_line(Vector2.ZERO, dir * length, Color(1.0, 0.9, 0.4), 4.0)


# --- flame + missiles: homing rockets that leave a burning crater -------------
class PhoenixRocket extends WeaponBase:
	var cooldown := 1.3
	func _init() -> void:
		weapon_id = "fus_phoenixrocket"
		display_name = "Phoenix Rocket"
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
		var dmg := 2.6 * player.damage_mult * (1.0 + 0.35 * (level - 1))
		for i in count:
			var m := MissileProj.new()
			m.source_pid = player.peer_id
			m.damage = dmg
			m.splash = (75.0 + 10.0 * (level - 1)) * player.area_mult
			m.life = 4.0 * player.duration_mult
			m.velocity = Vector2.from_angle(randf() * TAU) * 280.0
			m.fire_dps = 0.8 * player.damage_mult * (1.0 + 0.35 * (level - 1))
			m.fire_radius = (60.0 + 8.0 * (level - 1)) * player.area_mult
			m.fire_dur = 2.0 * player.duration_mult
			m.position = player.global_position
			player.get_parent().add_child(m)
		Sfx.play("missile", player.global_position)
		cooldown = 2.6 * player.rate_mult


# --- flame + orbit: orbiting blades that ignite and pulse fire ---------------
class BlazeHalo extends WeaponBase:
	const ORBIT_R := 80.0
	const BLADE_R := 11.0
	const HIT_CD := 0.5
	var angle := 0.0
	var hit_cd := {}
	var pulse_cd := 0.0
	func _init() -> void:
		weapon_id = "fus_blazehalo"
		display_name = "Blaze Halo"
	func _physics_process(delta: float) -> void:
		if player == null or player.downed:
			queue_redraw()
			return
		angle = fmod(angle + 2.8 / player.rate_mult * delta, TAU)
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
					e.take_hit(dmg, bp, Enemy.DMG_FIRE, player.peer_id)
					ignite(e, dmg)
					hit_cd[e.get_instance_id()] = HIT_CD * player.rate_mult
					break
		pulse_cd -= delta
		if pulse_cd <= 0.0:
			var radius := (110.0 + 20.0 * (level - 1)) * player.area_mult
			var pdmg := 1.6 * player.damage_mult * (1.0 + 0.4 * (level - 1))
			var any := false
			for e in get_tree().get_nodes_in_group("enemies"):
				if global_position.distance_to(e.global_position) <= radius + e.radius:
					e.take_hit(pdmg, global_position, Enemy.DMG_FIRE, player.peer_id)
					ignite(e, pdmg)
					any = true
			if any:
				var fx := RingFx.new()
				fx.position = global_position
				fx.radius = orbit_r
				fx.max_radius = radius
				fx.life = 0.35
				fx.color = Color(1.0, 0.5, 0.15)
				player.get_parent().add_child(fx)
				Sfx.play("flame", global_position)
				pulse_cd = 3.0 * player.rate_mult
			else:
				pulse_cd = 0.3
	func _draw() -> void:
		if player == null or player.downed:
			return
		var n := 2 + level
		var orbit_r := ORBIT_R * player.area_mult
		var blade_r := BLADE_R * player.area_mult
		for i in n:
			var p := Vector2.from_angle(angle + TAU * float(i) / n) * orbit_r
			draw_circle(p, blade_r, Color(1.0, 0.5, 0.15))
			draw_circle(p, blade_r * 0.5, Color(1.0, 0.85, 0.3))


# --- glaive + laser: boomerangs that fire a piercing beam on hit --------------
class PhotonDisc extends WeaponBase:
	var cooldown := 0.8
	func _init() -> void:
		weapon_id = "fus_photondisc"
		display_name = "Photon Disc"
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
		var dmg := 2.6 * player.damage_mult * (1.0 + 0.35 * (level - 1))
		for i in count:
			var g := GlaiveProj.new()
			g.source_pid = player.peer_id
			g.player = player
			g.velocity = base.rotated(deg_to_rad(20.0) * (i - (count - 1) / 2.0)) * 430.0
			g.damage = dmg
			g.hit_radius = 13.0 * player.area_mult
			g.on_hit = Callable(self, "_on_hit")
			g.position = player.global_position
			player.get_parent().add_child(g)
		Sfx.play("glaive", player.global_position)
		cooldown = 1.1 * player.rate_mult

	## Each glaive hit fires a short piercing beam along its travel direction.
	func _on_hit(e: Node2D, pos: Vector2) -> void:
		var dir: Vector2 = (e.global_position - player.global_position).normalized()
		var length := 220.0 * player.area_mult
		var dmg := 1.4 * player.damage_mult * (1.0 + 0.35 * (level - 1))
		for en in get_tree().get_nodes_in_group("enemies"):
			var rel: Vector2 = en.global_position - pos
			var along := rel.dot(dir)
			if along >= 0.0 and along <= length and (dir * along).distance_to(rel) <= 8.0 + en.radius:
				en.take_hit(dmg, pos, Enemy.DMG_ENERGY, player.peer_id)
				ignite(en, dmg)
		var fx := LightningFx.new()
		fx.points = [pos, pos + dir * length]
		player.get_parent().add_child(fx)


# --- glaive + missiles: homing rockets that burst into glaive shrapnel -------
class RotorMissile extends WeaponBase:
	var cooldown := 1.4
	func _init() -> void:
		weapon_id = "fus_rotormissile"
		display_name = "Rotor Missile"
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
		var dmg := 2.4 * player.damage_mult * (1.0 + 0.35 * (level - 1))
		for i in count:
			var m := MissileProj.new()
			m.source_pid = player.peer_id
			m.damage = dmg
			m.splash = (60.0 + 8.0 * (level - 1)) * player.area_mult
			m.life = 4.0 * player.duration_mult
			m.velocity = Vector2.from_angle(randf() * TAU) * 280.0
			m.shrapnel_count = 2 + level
			m.shrapnel_dmg = 1.6 * player.damage_mult * (1.0 + 0.3 * (level - 1))
			m.shrapnel_radius = 12.0 * player.area_mult
			m.position = player.global_position
			player.get_parent().add_child(m)
		Sfx.play("missile", player.global_position)
		cooldown = 2.6 * player.rate_mult


# --- glaive + orbit: orbiting blades that launch a returning glaive ----------
class BladeTempest extends WeaponBase:
	const ORBIT_R := 75.0
	const BLADE_R := 11.0
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
		angle = fmod(angle + 3.2 / player.rate_mult * delta, TAU)
		queue_redraw()
		var expired := []
		for k in hit_cd:
			hit_cd[k] -= delta
			if hit_cd[k] <= 0.0:
				expired.append(k)
		for k in expired:
			hit_cd.erase(k)
		var total := 2 + level
		# blades that have detached to strike leave a gap in the ring until they return
		var n := maxi(total - detached, 1)
		var orbit_r := ORBIT_R * player.area_mult
		var blade_r := BLADE_R * player.area_mult
		var dmg := 1.8 * player.damage_mult * (1.0 + 0.4 * (level - 1))
		for e in get_tree().get_nodes_in_group("enemies"):
			if hit_cd.has(e.get_instance_id()):
				continue
			for i in n:
				var bp: Vector2 = global_position + Vector2.from_angle(angle + TAU * float(i) / n) * orbit_r
				if bp.distance_to(e.global_position) <= blade_r + e.radius:
					e.take_hit(dmg, bp, Enemy.DMG_PHYS, player.peer_id)
					hit_cd[e.get_instance_id()] = HIT_CD * player.rate_mult
					break
		launch_cd -= delta
		if launch_cd <= 0.0 and detached < total - 1:
			var target := player.nearest_enemy(600.0)
			if target == null:
				launch_cd = 0.2
				return
			detached += 1
			var g := GlaiveProj.new()
			g.source_pid = player.peer_id
			g.player = player
			g.velocity = (target.global_position - player.global_position).normalized() * 460.0
			g.damage = 2.8 * player.damage_mult * (1.0 + 0.4 * (level - 1))
			g.hit_radius = 14.0 * player.area_mult
			g.position = global_position + Vector2.from_angle(angle) * orbit_r
			g.tree_exited.connect(func(): detached = maxi(detached - 1, 0))
			player.get_parent().add_child(g)
			Sfx.play("glaive", player.global_position)
			launch_cd = 1.8 * player.rate_mult
	func _draw() -> void:
		if player == null or player.downed:
			return
		var total := 2 + level
		var n := maxi(total - detached, 1)
		var orbit_r := ORBIT_R * player.area_mult
		var blade_r := BLADE_R * player.area_mult
		for i in n:
			var p := Vector2.from_angle(angle + TAU * float(i) / n) * orbit_r
			draw_circle(p, blade_r, Color(0.8, 0.8, 0.85))
			draw_circle(p, blade_r * 0.5, Color(0.6, 0.95, 0.85))


# --- glaive + venom: boomerangs that poison and leave toxic pools ------------
class PlagueBlade extends WeaponBase:
	var cooldown := 1.0
	func _init() -> void:
		weapon_id = "fus_plagueblade"
		display_name = "Plague Blade"
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
		var dmg := 2.4 * player.damage_mult * (1.0 + 0.35 * (level - 1))
		for i in count:
			var g := GlaiveProj.new()
			g.source_pid = player.peer_id
			g.player = player
			g.velocity = base.rotated(deg_to_rad(20.0) * (i - (count - 1) / 2.0)) * 430.0
			g.damage = dmg
			g.burn_dps = dmg * 0.4
			g.hit_radius = 14.0 * player.area_mult
			g.on_hit = Callable(self, "_on_hit")
			g.position = player.global_position
			player.get_parent().add_child(g)
		Sfx.play("venom", player.global_position)
		cooldown = 1.4 * player.rate_mult

	## Each glaive hit leaves a small toxic pool behind it.
	func _on_hit(_e: Node2D, pos: Vector2) -> void:
		var pud := VenomPuddle.new()
		pud.source_pid = player.peer_id
		pud.radius = (26.0 + 4.0 * (level - 1)) * player.area_mult
		pud.damage = 0.5 * player.damage_mult * (1.0 + 0.3 * (level - 1))
		pud.max_life = 1.6 * player.duration_mult
		pud.life = pud.max_life
		pud.position = pos
		player.get_parent().add_child(pud)


# --- laser + lightning: rotating beams that arc lightning on hit -------------
class IonStorm extends WeaponBase:
	const HIT_CD := 0.4
	var angle := 0.0
	var hit_cd := {}
	func _init() -> void:
		weapon_id = "fus_ionstorm"
		display_name = "Ion Storm"
	func _physics_process(delta: float) -> void:
		if player == null or player.downed:
			queue_redraw()
			return
		angle = fmod(angle + 1.8 / player.rate_mult * delta, TAU)
		queue_redraw()
		var expired := []
		for k in hit_cd:
			hit_cd[k] -= delta
			if hit_cd[k] <= 0.0:
				expired.append(k)
		for k in expired:
			hit_cd.erase(k)
		var beams := 1 + level
		var length := (170.0 + 25.0 * (level - 1)) * player.area_mult
		var dmg := 1.3 * player.damage_mult * (1.0 + 0.4 * (level - 1))
		for e in get_tree().get_nodes_in_group("enemies"):
			if hit_cd.has(e.get_instance_id()):
				continue
			var rel: Vector2 = e.global_position - global_position
			for b in beams:
				var dir := Vector2.from_angle(angle + TAU * float(b) / beams)
				var along := clampf(rel.dot(dir), 0.0, length)
				if (dir * along).distance_to(rel) <= 9.0 + e.radius:
					e.take_hit(dmg, global_position + dir * along, Enemy.DMG_ENERGY, player.peer_id)
					hit_cd[e.get_instance_id()] = HIT_CD * player.rate_mult
					_zap(e, dmg)
					break
	func _zap(src: Node2D, dmg: float) -> void:
		var zap_range := 170.0 * player.area_mult
		var best: Node2D = null
		var bd := zap_range * zap_range
		for e in get_tree().get_nodes_in_group("enemies"):
			if e == src or hit_cd.has(e.get_instance_id()):
				continue
			var d: float = src.global_position.distance_squared_to(e.global_position)
			if d < bd:
				bd = d
				best = e
		if best == null:
			return
		best.take_hit(dmg * 0.7, src.global_position, Enemy.DMG_ENERGY, player.peer_id)
		hit_cd[best.get_instance_id()] = HIT_CD * player.rate_mult
		var fx := LightningFx.new()
		fx.points = [src.global_position, best.global_position]
		player.get_parent().add_child(fx)
	func _draw() -> void:
		if player == null or player.downed:
			return
		var beams := 1 + level
		var length := (170.0 + 25.0 * (level - 1)) * player.area_mult
		for b in beams:
			var dir := Vector2.from_angle(angle + TAU * float(b) / beams)
			draw_line(Vector2.ZERO, dir * length, Color(0.7, 0.6, 1.0, 0.22), 12.0)
			draw_line(Vector2.ZERO, dir * length, Color(0.85, 0.8, 1.0), 2.5)
			draw_circle(dir * length, 7.0 * player.area_mult, Color(0.75, 0.7, 1.0))


# --- laser + missiles: rotating beams backed by homing rocket fire -----------
class BeamBattery extends WeaponBase:
	const HIT_CD := 0.4
	var angle := 0.0
	var hit_cd := {}
	var missile_cd := 0.0
	func _init() -> void:
		weapon_id = "fus_beambattery"
		display_name = "Beam Battery"
	func _physics_process(delta: float) -> void:
		if player == null or player.downed:
			queue_redraw()
			return
		angle = fmod(angle + 1.6 / player.rate_mult * delta, TAU)
		queue_redraw()
		var expired := []
		for k in hit_cd:
			hit_cd[k] -= delta
			if hit_cd[k] <= 0.0:
				expired.append(k)
		for k in expired:
			hit_cd.erase(k)
		var beams := 1 + level
		var length := (160.0 + 22.0 * (level - 1)) * player.area_mult
		var dmg := 1.1 * player.damage_mult * (1.0 + 0.4 * (level - 1))
		for e in get_tree().get_nodes_in_group("enemies"):
			if hit_cd.has(e.get_instance_id()):
				continue
			var rel: Vector2 = e.global_position - global_position
			for b in beams:
				var dir := Vector2.from_angle(angle + TAU * float(b) / beams)
				var along := clampf(rel.dot(dir), 0.0, length)
				if (dir * along).distance_to(rel) <= 9.0 + e.radius:
					e.take_hit(dmg, global_position + dir * along, Enemy.DMG_ENERGY, player.peer_id)
					ignite(e, dmg)
					hit_cd[e.get_instance_id()] = HIT_CD * player.rate_mult
					break
		missile_cd -= delta
		if missile_cd <= 0.0:
			var target := player.nearest_enemy(700.0)
			if target == null:
				missile_cd = 0.2
				return
			var m := MissileProj.new()
			m.source_pid = player.peer_id
			m.damage = 2.4 * player.damage_mult * (1.0 + 0.35 * (level - 1))
			m.splash = (65.0 + 8.0 * (level - 1)) * player.area_mult
			m.life = 4.0 * player.duration_mult
			m.velocity = Vector2.from_angle(randf() * TAU) * 280.0
			m.position = global_position
			player.get_parent().add_child(m)
			Sfx.play("missile", global_position)
			missile_cd = 2.4 * player.rate_mult
	func _draw() -> void:
		if player == null or player.downed:
			return
		var beams := 1 + level
		var length := (160.0 + 22.0 * (level - 1)) * player.area_mult
		for b in beams:
			var dir := Vector2.from_angle(angle + TAU * float(b) / beams)
			draw_line(Vector2.ZERO, dir * length, Color(1.0, 0.7, 0.3, 0.22), 12.0)
			draw_line(Vector2.ZERO, dir * length, Color(1.0, 0.9, 0.6), 2.5)
			draw_circle(dir * length, 7.0 * player.area_mult, Color(1.0, 0.8, 0.4))


# --- laser + venom: rotating beams that corrode and seed toxic pools ---------
class AcidRay extends WeaponBase:
	const HIT_CD := 0.4
	var angle := 0.0
	var hit_cd := {}
	var pool_cd := 0.0
	func _init() -> void:
		weapon_id = "fus_acidray"
		display_name = "Acid Ray"
	func _physics_process(delta: float) -> void:
		if player == null or player.downed:
			queue_redraw()
			return
		angle = fmod(angle + 1.6 / player.rate_mult * delta, TAU)
		queue_redraw()
		var expired := []
		for k in hit_cd:
			hit_cd[k] -= delta
			if hit_cd[k] <= 0.0:
				expired.append(k)
		for k in expired:
			hit_cd.erase(k)
		var beams := 1 + level
		var length := (160.0 + 22.0 * (level - 1)) * player.area_mult
		var dmg := 1.0 * player.damage_mult * (1.0 + 0.4 * (level - 1))
		for e in get_tree().get_nodes_in_group("enemies"):
			if hit_cd.has(e.get_instance_id()):
				continue
			var rel: Vector2 = e.global_position - global_position
			for b in beams:
				var dir := Vector2.from_angle(angle + TAU * float(b) / beams)
				var along := clampf(rel.dot(dir), 0.0, length)
				if (dir * along).distance_to(rel) <= 9.0 + e.radius:
					e.take_hit(dmg, global_position + dir * along, Enemy.DMG_ENERGY, player.peer_id)
					e.apply_burn(dmg * 0.5, 1.5 * player.duration_mult)
					hit_cd[e.get_instance_id()] = HIT_CD * player.rate_mult
					break
		pool_cd -= delta
		if pool_cd <= 0.0:
			var dir := Vector2.from_angle(angle)
			var pud := VenomPuddle.new()
			pud.source_pid = player.peer_id
			pud.radius = (45.0 + 6.0 * (level - 1)) * player.area_mult
			pud.damage = 0.7 * player.damage_mult * (1.0 + 0.4 * (level - 1))
			pud.max_life = 2.0 * player.duration_mult
			pud.life = pud.max_life
			pud.position = global_position + dir * length
			player.get_parent().add_child(pud)
			Sfx.play("venom", global_position)
			pool_cd = 2.5 * player.rate_mult
	func _draw() -> void:
		if player == null or player.downed:
			return
		var beams := 1 + level
		var length := (160.0 + 22.0 * (level - 1)) * player.area_mult
		for b in beams:
			var dir := Vector2.from_angle(angle + TAU * float(b) / beams)
			draw_line(Vector2.ZERO, dir * length, Color(0.5, 0.9, 0.3, 0.22), 12.0)
			draw_line(Vector2.ZERO, dir * length, Color(0.75, 1.0, 0.5), 2.5)
			draw_circle(dir * length, 7.0 * player.area_mult, Color(0.6, 1.0, 0.4))


# --- lightning + missiles: homing rockets that chain lightning on impact -----
class EMPMissile extends WeaponBase:
	var cooldown := 1.3
	func _init() -> void:
		weapon_id = "fus_empmissile"
		display_name = "EMP Missile"
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
		var dmg := 2.4 * player.damage_mult * (1.0 + 0.35 * (level - 1))
		for i in count:
			var m := MissileProj.new()
			m.source_pid = player.peer_id
			m.damage = dmg
			m.splash = (65.0 + 8.0 * (level - 1)) * player.area_mult
			m.life = 4.0 * player.duration_mult
			m.velocity = Vector2.from_angle(randf() * TAU) * 280.0
			m.chain_count = 2 + level
			m.chain_dmg = 1.8 * player.damage_mult * (1.0 + 0.35 * (level - 1))
			m.chain_range = 200.0 * player.area_mult
			m.position = player.global_position
			player.get_parent().add_child(m)
		Sfx.play("missile", player.global_position)
		cooldown = 2.6 * player.rate_mult


# --- missiles + orbit: orbiting blades backed by homing rocket fire ----------
class RocketHalo extends WeaponBase:
	const ORBIT_R := 78.0
	const BLADE_R := 11.0
	const HIT_CD := 0.5
	const TAG_DUR := 2.5
	var angle := 0.0
	var hit_cd := {}
	var tagged := {}  # enemy instance id -> remaining lock time
	var missile_cd := 0.0
	func _init() -> void:
		weapon_id = "fus_rockethalo"
		display_name = "Rocket Halo"
	func _physics_process(delta: float) -> void:
		if player == null or player.downed:
			queue_redraw()
			return
		angle = fmod(angle + 2.8 / player.rate_mult * delta, TAU)
		queue_redraw()
		var expired := []
		for k in hit_cd:
			hit_cd[k] -= delta
			if hit_cd[k] <= 0.0:
				expired.append(k)
		for k in expired:
			hit_cd.erase(k)
		var texpired := []
		for k in tagged:
			tagged[k] -= delta
			if tagged[k] <= 0.0:
				texpired.append(k)
		for k in texpired:
			tagged.erase(k)
		var n := 2 + level
		var orbit_r := ORBIT_R * player.area_mult
		var blade_r := BLADE_R * player.area_mult
		var dmg := 2.0 * player.damage_mult * (1.0 + 0.4 * (level - 1))
		# blades that strike an enemy paint a lock-on target for the missiles
		for e in get_tree().get_nodes_in_group("enemies"):
			if hit_cd.has(e.get_instance_id()):
				continue
			for i in n:
				var bp: Vector2 = global_position + Vector2.from_angle(angle + TAU * float(i) / n) * orbit_r
				if bp.distance_to(e.global_position) <= blade_r + e.radius:
					e.take_hit(dmg, bp, Enemy.DMG_PHYS, player.peer_id)
					hit_cd[e.get_instance_id()] = HIT_CD * player.rate_mult
					tagged[e.get_instance_id()] = TAG_DUR * player.duration_mult
					break
		missile_cd -= delta
		if missile_cd <= 0.0:
			var lock: Node2D = null
			for e in get_tree().get_nodes_in_group("enemies"):
				if tagged.has(e.get_instance_id()):
					lock = e
					break
			if lock == null:
				missile_cd = 0.2
				return
			var m := MissileProj.new()
			m.source_pid = player.peer_id
			m.target = lock
			m.damage = 3.0 * player.damage_mult * (1.0 + 0.4 * (level - 1))
			m.splash = (75.0 + 10.0 * (level - 1)) * player.area_mult
			m.life = 4.0 * player.duration_mult
			m.velocity = (lock.global_position - global_position).normalized() * 280.0
			m.position = global_position
			player.get_parent().add_child(m)
			Sfx.play("missile", global_position)
			missile_cd = 1.6 * player.rate_mult
	func _draw() -> void:
		if player == null or player.downed:
			return
		var n := 2 + level
		var orbit_r := ORBIT_R * player.area_mult
		var blade_r := BLADE_R * player.area_mult
		for i in n:
			var p := Vector2.from_angle(angle + TAU * float(i) / n) * orbit_r
			draw_circle(p, blade_r, Color(0.85, 0.6, 0.3))
			draw_circle(p, blade_r * 0.5, Color(1.0, 0.85, 0.5))


# --- missiles + venom: homing rockets that burst into a toxic cloud ----------
class PlagueRocket extends WeaponBase:
	var cooldown := 1.3
	func _init() -> void:
		weapon_id = "fus_plaguerocket"
		display_name = "Plague Rocket"
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
		var dmg := 2.6 * player.damage_mult * (1.0 + 0.35 * (level - 1))
		for i in count:
			var m := MissileProj.new()
			m.source_pid = player.peer_id
			m.damage = dmg
			m.splash = (70.0 + 10.0 * (level - 1)) * player.area_mult
			m.life = 4.0 * player.duration_mult
			m.velocity = Vector2.from_angle(randf() * TAU) * 280.0
			m.venom_dps = 0.8 * player.damage_mult * (1.0 + 0.35 * (level - 1))
			m.venom_radius = (65.0 + 9.0 * (level - 1)) * player.area_mult
			m.venom_dur = 2.5 * player.duration_mult
			m.position = player.global_position
			player.get_parent().add_child(m)
		Sfx.play("venom", player.global_position)
		cooldown = 2.6 * player.rate_mult
