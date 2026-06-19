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
	"flame|venom": {"name": "Purgatory", "desc": "an eerie field that burns and marks foes inside it -- marked enemies take extra damage, slow harder, and can't burn out"},
	"gravity|nova": {"name": "Singularity", "desc": "a vortex that yanks enemies inward every second, then collapses into a detonation that hits harder the more enemies it caught"},
	"mines|missiles": {"name": "Cluster Bomb", "desc": "mines that spray homing rockets on blast"},
	"laser|orbit": {"name": "Prism Halo", "desc": "prisms drop around you, linked to you and each other by damage beams"},
	"frost|glaive": {"name": "Glacial Edge", "desc": "boomerangs that freeze and bleed"},
	"bolt|lightning": {"name": "Railgun", "desc": "a piercing rail-shot that electrifies its whole line"},
	"flame|nova": {"name": "Supernova", "desc": "a huge blast that leaves a burning field"},
	"frost|orbit": {"name": "Frost Halo", "desc": "orbiting blades that freeze on contact"},
	"frost|gravity": {"name": "Glacier", "desc": "a huge frost vortex pulsing cold waves; 3 waves fully freezes a foe"},
	"glaive|lightning": {"name": "Storm Disc", "desc": "a thunder shuriken that loops between random points and the player, arcing lightning to nearby foes"},
	"flame|mines": {"name": "Napalm Mine", "desc": "mines that leave a burning pool on blast"},
	"missiles|nova": {"name": "Cluster Warhead", "desc": "straight-flying warheads that erupt into a heavy shockwave, shoving everything in the blast outward"},
	"gravity|venom": {"name": "Black Bog", "desc": "a vortex that leaves a toxic pool where it forms"},
	"orbit|venom": {"name": "Toxic Halo", "desc": "orbiting blades that poison on contact and paint a rotating ring of toxic ground"},
	"nova|orbit": {"name": "Pulsar", "desc": "orbiting balls that periodically swarm a random foe, ring around it, then rush in and detonate"},
	"bolt|frost": {"name": "Frost Lance", "desc": "a piercing volley of chilling lances that shatter already-frozen foes"},
	"lightning|venom": {"name": "Ground Current", "desc": "a crackling field where every enemy caught inside becomes its own lightning source, chaining to nearby foes"},
	"lightning|orbit": {"name": "Tesla Halo", "desc": "orbiting blades that zap nearby foes"},
	"flame|lightning": {"name": "Plasma Storm", "desc": "a drifting cloud that burns on contact and arcs lightning to nearby foes"},
	"glaive|nova": {"name": "Cyclone", "desc": "whirling glaives around a pulsing core"},
	"missiles|turret": {"name": "Missile Battery", "desc": "a deployed launcher firing homing salvos"},
	"laser|turret": {"name": "Beam Sentry", "desc": "a deployed turret that sweeps a beam"},
	"frost|turret": {"name": "Cryo Sentry", "desc": "a deployed turret firing slowing shots"},
	"laser|nova": {"name": "Plasma Pulse", "desc": "a ring of light that follows you, slowly growing outward"},
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
	"mines|orbit": {"name": "Bouncy Grenade", "desc": "a barrage of grenades that bounce between enemies, exploding hardest on the final hop"},
	"bolt|flame": {"name": "Incendiary Rounds", "desc": "bolts that ignite the ground on impact, leaving a burning field"},
	"bolt|orbit": {"name": "Scatter Shot", "desc": "a ring of bolts fired in all directions"},
	"bolt|glaive": {"name": "Ricochet", "desc": "bolts that arc to the next enemy on every hit"},
	"bolt|gravity": {"name": "Gravity Round", "desc": "bolts that form a gravity vortex on impact"},
	"bolt|laser": {"name": "Charge Round", "desc": "charges up a heavy piercing round that punches through every enemy in its path"},
	"bolt|mines": {"name": "Sapper Round", "desc": "bolts that arm a proximity mine on impact"},
	"bolt|venom": {"name": "Corrosive Round", "desc": "bolts that shatter into a corrosive splash on hit"},
	"frost|laser": {"name": "Cryo Beam", "desc": "rotating ice beams that chill everything they sweep"},
	"frost|mines": {"name": "Glacial Mine", "desc": "mines that detonate into a total freeze, halting enemies caught in the blast"},
	"frost|missiles": {"name": "Cryo Missile", "desc": "homing missiles that slow all targets in the blast"},
	"frost|venom": {"name": "Frostbite", "desc": "a pool that chills and poisons everything inside"},
	"flame|gravity": {"name": "Cinder Vortex", "desc": "a vortex that drags enemies into a burning pool"},
	"gravity|laser": {"name": "Accretion Beam", "desc": "a vortex ringed by rotating energy beams"},
	"gravity|lightning": {"name": "Storm Vortex", "desc": "a vortex that arcs lightning between everything it traps"},
	"gravity|mines": {"name": "Implosion Mine", "desc": "a vortex that seeds mines around its collapsing core"},
	"gravity|missiles": {"name": "Carpet Bombing", "desc": "marks a random nearby foe's spot, then calls in a missile barrage on random points inside that zone"},
	"glaive|mines": {"name": "Shrapnel Mine", "desc": "mines that burst into a spray of glaive shrapnel that shuttles back and forth until it fades"},
	"laser|mines": {"name": "Beam Mine", "desc": "mines that link sustained laser beams to each other; enemy contact arms a long fuse, still beaming, before it detonates"},
	"lightning|mines": {"name": "Tesla Mine", "desc": "mines placed inert, projecting a shocking field that chains lightning between enemies; once the inert period ends, contact detonates them like a normal mine"},
	"mines|nova": {"name": "Nova Mine", "desc": "mines that pulse a second energy blast on detonation"},
	"mines|venom": {"name": "Toxic Mine", "desc": "mines that leave a toxic pool on blast"},
	"flame|glaive": {"name": "Inferno Blade", "desc": "boomerangs that ignite foes and leave fire pools where they strike"},
	"flame|laser": {"name": "Solar Lance", "desc": "a continuous beam of searing light"},
	"flame|missiles": {"name": "Phoenix Rocket", "desc": "homing rockets that leave a burning crater on impact"},
	"flame|orbit": {"name": "Blaze Halo", "desc": "orbiting blades that ignite on contact and pulse a ring of fire"},
	"glaive|laser": {"name": "Photon Disc", "desc": "boomerangs that fire a piercing beam from every hit"},
	"glaive|missiles": {"name": "Rotor Missile", "desc": "homing rockets that burst into glaive shrapnel"},
	"glaive|orbit": {"name": "Halo Comet", "desc": "orbiting balls that periodically spurt outward like a comet's tail, hitting harder while extended"},
	"glaive|venom": {"name": "Plague Blade", "desc": "boomerangs that poison foes and leave toxic pools where they strike"},
	"laser|lightning": {"name": "Ion Storm", "desc": "rotating beams that arc lightning to nearby foes"},
	"laser|missiles": {"name": "Beam Battery", "desc": "harmless rotating beams paint targets; on cooldown, every painted enemy takes a homing, fire-bursting missile"},
	"laser|venom": {"name": "Acid Ray", "desc": "rotating beams that corrode foes and seed toxic pools"},
	"lightning|missiles": {"name": "EMP Missile", "desc": "homing rockets that chain lightning on impact"},
	"missiles|orbit": {"name": "Concorde", "desc": "a growing paper-plane missile that warps to the far side of the arena instead of dying at the border, flying until a very long lifetime runs out"},
	"missiles|venom": {"name": "Plague Rocket", "desc": "homing rockets that burst into a toxic cloud"},
}


static func key(a: String, b: String) -> String:
	var ids := [a, b]
	ids.sort()
	return "|".join(ids)


static func info(a: String, b: String) -> Dictionary:
	return INFO.get(key(a, b), {})


## Merging two weapons of tiers (ta, tb) yields a weapon of tier max(ta, tb) + 1
## (base+base -> tier 1 signature fusion; signature+signature -> tier 2 amalgam).
static func merged_tier(ta: int, tb: int) -> int:
	return maxi(ta, tb) + 1


## Merge eligibility: only two weapons of the SAME kind merge — base+base (tier 0+0
## -> signature fusion) or signature+signature (tier 1+1 -> amalgam). tier >=2 is an
## amalgam (WeaponFused), which is TERMINAL: no base+fusion mixing, no amalgam re-merge.
static func can_merge(ta: int, tb: int) -> bool:
	return ta == tb and ta <= 1


static func make(a: String, b: String) -> WeaponBase:
	match key(a, b):
		"bolt|nova": return FusPlasmaBurst.new()
		"frost|lightning": return FusCryoshock.new()
		"flame|venom": return FusPurgatory.new()
		"gravity|nova": return FusSingularity.new()
		"mines|missiles": return FusClusterBomb.new()
		"laser|orbit": return FusPrismHalo.new()
		"frost|glaive": return FusGlacialEdge.new()
		"bolt|lightning": return FusRailgun.new()
		"flame|nova": return FusSupernova.new()
		"frost|orbit": return FusFrostHalo.new()
		"frost|gravity": return FusGlacier.new()
		"glaive|lightning": return FusStormDisc.new()
		"flame|mines": return FusNapalmMine.new()
		"missiles|nova": return FusClusterWarhead.new()
		"gravity|venom": return FusBlackBog.new()
		"orbit|venom": return FusToxicHalo.new()
		"nova|orbit": return FusPulsar.new()
		"bolt|frost": return FusFrostLance.new()
		"lightning|venom": return FusGroundCurrent.new()
		"lightning|orbit": return FusTeslaHalo.new()
		"flame|lightning": return FusPlasmaStorm.new()
		"glaive|nova": return FusCyclone.new()
		"missiles|turret": return FusMissileBattery.new()
		"laser|turret": return FusBeamSentry.new()
		"frost|turret": return FusCryoSentry.new()
		"laser|nova": return FusPlasmaPulse.new()
		"bolt|missiles": return FusBarrage.new()
		"nova|venom": return FusToxicNova.new()
		"bolt|turret": return FusGunTurret.new()
		"orbit|turret": return FusHaloTurret.new()
		"nova|turret": return FusPulseTurret.new()
		"glaive|turret": return FusGlaiveTurret.new()
		"lightning|turret": return FusTeslaTurret.new()
		"flame|turret": return FusFlameTurret.new()
		"mines|turret": return FusMineLayer.new()
		"gravity|turret": return FusSingularityTurret.new()
		"turret|venom": return FusToxicTurret.new()
		"frost|nova": return FusAbsoluteZero.new()
		"flame|frost": return FusThermalShock.new()
		"gravity|orbit": return FusEventHorizon.new()
		"glaive|gravity": return FusVortexBlade.new()
		"lightning|nova": return FusThunderclap.new()
		"mines|orbit": return FusBouncyGrenade.new()
		"bolt|flame": return FusIncendiaryRounds.new()
		"bolt|orbit": return FusScatterShot.new()
		"bolt|glaive": return FusRicochet.new()
		"bolt|gravity": return FusGravityRound.new()
		"bolt|laser": return FusChargeRound.new()
		"bolt|mines": return FusSapperRound.new()
		"bolt|venom": return FusCorrosiveRound.new()
		"frost|laser": return FusCryoBeam.new()
		"frost|mines": return FusGlacialMine.new()
		"frost|missiles": return FusCryoMissile.new()
		"frost|venom": return FusFrostbite.new()
		"flame|gravity": return FusCinderVortex.new()
		"gravity|laser": return FusAccretionBeam.new()
		"gravity|lightning": return FusStormVortex.new()
		"gravity|mines": return FusImplosionMine.new()
		"gravity|missiles": return FusCarpetBombing.new()
		"glaive|mines": return FusShrapnelMine.new()
		"laser|mines": return FusBeamMine.new()
		"lightning|mines": return FusTeslaMine.new()
		"mines|nova": return FusNovaMine.new()
		"mines|venom": return FusToxicMine.new()
		"flame|glaive": return FusInfernoBlade.new()
		"flame|laser": return FusSolarLance.new()
		"flame|missiles": return FusPhoenixRocket.new()
		"flame|orbit": return FusBlazeHalo.new()
		"glaive|laser": return FusPhotonDisc.new()
		"glaive|missiles": return FusRotorMissile.new()
		"glaive|orbit": return FusHaloComet.new()
		"glaive|venom": return FusPlagueBlade.new()
		"laser|lightning": return FusIonStorm.new()
		"laser|missiles": return FusBeamBattery.new()
		"laser|venom": return FusAcidRay.new()
		"lightning|missiles": return FusEMPMissile.new()
		"missiles|orbit": return FusConcorde.new()
		"missiles|venom": return FusPlagueRocket.new()
	return null

# Fusion weapon classes now live one-per-file in scripts/weapons/fusions/
