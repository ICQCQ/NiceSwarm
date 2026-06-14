class_name EnemyConfig
extends RefCounted
## Enemy archetype data — tune classes/tiers here. Used by EnemySpawner as CLASSES.
## (See ENEMY_DESIGN.md for the field meanings and add-a-class checklist.)

# Enemy archetypes. Each class is an ordered list of tiers; a higher tier is a
# direct upgrade of the one before, and which tier spawns rises with time + level
# + difficulty (see EnemySpawner.class_tier). Add a class or a tier here —
# EnemySpawner.build_type_registry flattens them into stable network ids automatically.
const CLASSES := {
	"brawler": [  # baseline chasers
		{"name": "Grunt", "hp0": 2.0, "hpk": 1.5, "spd": 85.0, "spdk": 5.0, "r": 12.0, "dmg": 1, "xp": 1, "col": Color(0.85, 0.3, 0.35), "shape": "circle"},
		{"name": "Bruiser", "hp0": 6.0, "hpk": 2.5, "spd": 95.0, "spdk": 5.0, "r": 15.0, "dmg": 1, "xp": 2, "col": Color(0.9, 0.42, 0.32), "shape": "circle"},
		{"name": "Reaver", "hp0": 15.0, "hpk": 4.0, "spd": 105.0, "spdk": 4.0, "r": 17.0, "dmg": 2, "xp": 3, "col": Color(0.98, 0.52, 0.36), "shape": "circle"},
	],
	"rusher": [  # fast and fragile, arrowheads that dart at you
		{"name": "Runner", "hp0": 1.0, "hpk": 0.7, "spd": 165.0, "spdk": 4.0, "r": 9.0, "dmg": 1, "xp": 1, "col": Color(0.95, 0.6, 0.2), "shape": "triangle"},
		{"name": "Sprinter", "hp0": 3.0, "hpk": 1.2, "spd": 205.0, "spdk": 4.0, "r": 10.0, "dmg": 1, "xp": 2, "col": Color(1.0, 0.72, 0.2), "shape": "triangle"},
	],
	"tank": [  # big, slow, heavy contact damage; drop pickups
		{"name": "Brute", "hp0": 14.0, "hpk": 6.0, "spd": 55.0, "spdk": 0.0, "r": 24.0, "dmg": 2, "xp": 5, "col": Color(0.6, 0.2, 0.7), "shape": "hex", "pull_imm": true},
		{"name": "Behemoth", "hp0": 40.0, "hpk": 10.0, "spd": 52.0, "spdk": 0.0, "r": 30.0, "dmg": 3, "xp": 9, "col": Color(0.72, 0.26, 0.82), "shape": "hex", "pull_imm": true},
	],
	"caster": [  # ranged; telegraphed strikes (pattern escalates per tier).
		# cdt = seconds between casts, cr = strike radius, cd = strike damage, pattern: 0 single (leads you) / 1 line / 2 ring
		# uniform_tier (on tier 0, applies to the whole class): every unlocked
		# tier is equally likely — Bomber/Diviner/Oracle stay evenly mixed
		# instead of skewing toward Oracle late-game (see EnemySpawner.class_tier).
		{"name": "Bomber", "hp0": 10.0, "hpk": 4.0, "spd": 110.0, "spdk": 1.0, "r": 15.0, "dmg": 1, "xp": 4, "col": Color(0.55, 0.12, 0.12), "shape": "circle", "caster": true, "pattern": 0, "cr": 115.0, "cd": 2, "cdt": 2.0, "keep": 280.0, "uniform_tier": true},
		{"name": "Diviner", "hp0": 14.0, "hpk": 5.0, "spd": 90.0, "spdk": 0.0, "r": 16.0, "dmg": 1, "xp": 6, "col": Color(0.4, 0.2, 0.6), "shape": "circle", "caster": true, "pattern": 1, "cr": 85.0, "cd": 2, "cdt": 2.6, "keep": 330.0},
		{"name": "Oracle", "hp0": 24.0, "hpk": 6.0, "spd": 80.0, "spdk": 0.0, "r": 18.0, "dmg": 2, "xp": 9, "col": Color(0.55, 0.25, 0.72), "shape": "circle", "caster": true, "pattern": 2, "cr": 75.0, "cd": 2, "cdt": 3.0, "keep": 360.0},
	],
	"warden": [  # armored — shrugs off a fraction of every hit (resist); focus-fire to drop
		{"name": "Shieldling", "hp0": 10.0, "hpk": 3.0, "spd": 70.0, "spdk": 1.0, "r": 16.0, "dmg": 1, "xp": 3, "col": Color(0.55, 0.6, 0.72), "shape": "square", "resist": 0.4, "pull_imm": true},
		{"name": "Bulwark", "hp0": 24.0, "hpk": 6.0, "spd": 66.0, "spdk": 1.0, "r": 20.0, "dmg": 2, "xp": 6, "col": Color(0.62, 0.67, 0.8), "shape": "square", "resist": 0.55, "pull_imm": true},
	],
	"burster": [  # follows then SPITS a ring of enemy bullets (shards) on death — dodge the burst
		{"name": "Spore", "hp0": 8.0, "hpk": 2.0, "spd": 72.0, "spdk": 1.0, "r": 14.0, "dmg": 1, "xp": 2, "col": Color(0.4, 0.72, 0.42), "shape": "star", "burst": 6},
		{"name": "Brood", "hp0": 18.0, "hpk": 4.0, "spd": 70.0, "spdk": 1.0, "r": 18.0, "dmg": 1, "xp": 4, "col": Color(0.45, 0.82, 0.46), "shape": "star", "burst": 9},
	],
	"shard": [  # the enemy bullet a Burster spits: flies straight, phases, expires, 1 hit kills it
		{"name": "Shard", "hp0": 1.0, "hpk": 0.0, "spd": 230.0, "spdk": 0.0, "r": 7.0, "dmg": 1, "xp": 0, "col": Color(0.6, 0.95, 0.6), "shape": "triangle", "move": 3, "phase": true, "cc_imm": true, "bullet": true, "life": 2.2, "pull_imm": true},
	],
	"sentinel": [  # phases an impenetrable shield on/off — strike between phases
		{"name": "Sentinel", "hp0": 12.0, "hpk": 4.0, "spd": 80.0, "spdk": 2.0, "r": 16.0, "dmg": 1, "xp": 4, "col": Color(0.35, 0.55, 0.7), "shape": "square", "shield_cycle": 2.8, "shield_time": 1.4, "pull_imm": true},
		{"name": "Aegis", "hp0": 26.0, "hpk": 7.0, "spd": 82.0, "spdk": 2.0, "r": 19.0, "dmg": 2, "xp": 7, "col": Color(0.4, 0.62, 0.78), "shape": "square", "shield_cycle": 2.4, "shield_time": 1.6, "pull_imm": true},
	],
	"wisp": [  # immune to ENERGY; drifts randomly (doesn't chase), hard to predict
		{"name": "Mote", "hp0": 8.0, "hpk": 2.5, "spd": 110.0, "spdk": 3.0, "r": 11.0, "dmg": 1, "xp": 3, "col": Color(0.8, 0.7, 1.0), "shape": "diamond", "immune": Enemy.DMG_ENERGY, "move": 1},
		{"name": "Wisp", "hp0": 16.0, "hpk": 4.5, "spd": 120.0, "spdk": 3.0, "r": 13.0, "dmg": 1, "xp": 5, "col": Color(0.86, 0.76, 1.0), "shape": "diamond", "immune": Enemy.DMG_ENERGY, "move": 1},
	],
	"bouncer": [  # ricochets around the arena, phases through everything, can't be interrupted
		# special population: NOT in SPAWN_POOL — EnemySpawner.run_spawning tops
		# bouncers up to their own (growing) cap once BOUNCER_UNLOCK passes,
		# independent of the normal pool's desired_pop.
		{"name": "Caroms", "hp0": 14.0, "hpk": 3.0, "spd": 190.0, "spdk": 2.0, "r": 14.0, "dmg": 2, "xp": 4, "col": Color(0.95, 0.85, 0.3), "shape": "diamond", "move": 2, "phase": true, "cc_imm": true, "pull_imm": true},
		{"name": "Pinball", "hp0": 28.0, "hpk": 5.0, "spd": 220.0, "spdk": 2.0, "r": 16.0, "dmg": 2, "xp": 7, "col": Color(1.0, 0.9, 0.35), "shape": "diamond", "move": 2, "phase": true, "cc_imm": true, "pull_imm": true},
	],
	"disruptor": [  # telegraphs zones that don't hurt but slow you and lock your dash
		{"name": "Hexer", "hp0": 12.0, "hpk": 4.0, "spd": 95.0, "spdk": 1.0, "r": 15.0, "dmg": 1, "xp": 5, "col": Color(0.6, 0.3, 0.7), "shape": "diamond", "caster": true, "pattern": 0, "effect": 1, "cr": 100.0, "cd": 0, "cdt": 2.4, "keep": 300.0},
		{"name": "Nullifier", "hp0": 20.0, "hpk": 5.0, "spd": 95.0, "spdk": 1.0, "r": 17.0, "dmg": 1, "xp": 7, "col": Color(0.66, 0.34, 0.78), "shape": "diamond", "caster": true, "pattern": 1, "effect": 1, "cr": 90.0, "cd": 0, "cdt": 2.8, "keep": 320.0},
	],
	"defiler": [  # lays LINGERING disrupt fields on the ground - deny areas, force movement
		{"name": "Warlock", "hp0": 14.0, "hpk": 4.0, "spd": 85.0, "spdk": 1.0, "r": 16.0, "dmg": 1, "xp": 5, "col": Color(0.45, 0.25, 0.6), "shape": "diamond", "caster": true, "pattern": 0, "effect": 2, "cr": 95.0, "cd": 0, "cdt": 3.2, "keep": 320.0},
		{"name": "Defiler", "hp0": 24.0, "hpk": 5.0, "spd": 82.0, "spdk": 1.0, "r": 18.0, "dmg": 1, "xp": 8, "col": Color(0.5, 0.28, 0.66), "shape": "diamond", "caster": true, "pattern": 1, "effect": 2, "cr": 85.0, "cd": 0, "cdt": 3.6, "keep": 340.0},
	],
	"elite": [  # tanky specials that always drop a chest
		{"name": "Elite", "hp0": 40.0, "hpk": 18.0, "spd": 100.0, "spdk": 0.0, "r": 18.0, "dmg": 1, "xp": 8, "col": Color(0.95, 0.35, 0.5), "shape": "circle", "elite": true, "pull_imm": true},
		{"name": "Champion", "hp0": 95.0, "hpk": 30.0, "spd": 110.0, "spdk": 0.0, "r": 22.0, "dmg": 2, "xp": 14, "col": Color(1.0, 0.45, 0.6), "shape": "circle", "elite": true, "pull_imm": true},
	],
	# bosses: spawned by EnemySpawner after enough total kills (BOSS_KILL_BASE,
	# then +BOSS_KILL_INTERVAL each time), tier escalates per boss. Each is hard
	# to kill via a distinct mechanic (not just hp), with a slam_pattern that
	# fires a map-wide/pattern telegraph attack independent of normal chase AI.
	"boss": [
		# Juggernaut: phases an unbreakable shield, immune to slow/knockback, and
		# slams a checkerboard of strikes centered on itself — find the gaps.
		{"name": "Juggernaut", "hp0": 450.0, "hpk": 50.0, "spd": 50.0, "spdk": 0.0, "r": 34.0, "dmg": 3, "xp": 50, "col": Color(0.55, 0.05, 0.05), "shape": "hex", "elite": true, "pull_imm": true, "cc_imm": true, "shield_cycle": 4.0, "shield_time": 2.5, "boss": true, "slam_pattern": 3, "slam_radius": 110.0, "slam_damage": 4, "slam_cooldown": 6.0},
		# Harbinger: cycles its elemental immunity every few seconds — match your
		# damage type — and sweeps a rotating line of strikes around the target.
		{"name": "Harbinger", "hp0": 750.0, "hpk": 70.0, "spd": 55.0, "spdk": 0.0, "r": 30.0, "dmg": 4, "xp": 70, "col": Color(0.35, 0.05, 0.5), "shape": "star", "elite": true, "pull_imm": true, "boss": true, "immune_cycle": 4.0, "immune_pool": [Enemy.DMG_PHYS, Enemy.DMG_FIRE, Enemy.DMG_ICE, Enemy.DMG_ENERGY], "slam_pattern": 4, "slam_radius": 90.0, "slam_damage": 3, "slam_cooldown": 4.5},
		# Eclipse: enrages as it's worn down (armor climbs toward 50% near death)
		# and calls in reinforcements while slamming a checkerboard grid.
		{"name": "Eclipse", "hp0": 1100.0, "hpk": 90.0, "spd": 50.0, "spdk": 0.0, "r": 38.0, "dmg": 5, "xp": 100, "col": Color(0.25, 0.05, 0.1), "shape": "square", "elite": true, "pull_imm": true, "boss": true, "enrage_resist": 0.5, "summon_cls": "brawler", "summon_count": 2, "summon_cooldown": 9.0, "slam_pattern": 3, "slam_radius": 120.0, "slam_damage": 4, "slam_cooldown": 5.5},
	],
}

# Weighted regular spawn pool. Each row becomes available once `elapsed >=
# unlock`; EnemySpawner.run_spawning picks a class via weighted random over
# every currently-unlocked row. "bouncer" is NOT in this pool — it's a special
# population maintained separately (its own growing cap; see run_spawning).
const SPAWN_POOL := [
	{"cls": "brawler",   "weight": 3, "unlock": 0.0},
	{"cls": "rusher",    "weight": 2, "unlock": 45.0},
	{"cls": "wisp",      "weight": 1, "unlock": 90.0},
	{"cls": "warden",    "weight": 1, "unlock": 120.0},
	{"cls": "sentinel",  "weight": 1, "unlock": 150.0},
	{"cls": "burster",   "weight": 1, "unlock": 180.0},
	{"cls": "disruptor", "weight": 1, "unlock": 210.0},
	{"cls": "defiler",   "weight": 1, "unlock": 300.0},
]

# Periodic "special" spawns (tanks/elites/casters), one per key. Each fires on
# its own accumulator once `elapsed >= unlock`. `interval` is a flat cooldown;
# `interval_hi`/`interval_lo` instead lerp the cooldown by current heat
# (0 = interval_hi, 1 = interval_lo) so these ramp up when the party is ahead.
const SPAWN_SPECIALS := {
	"tank":   {"cls": "tank",   "unlock": 90.0,  "interval": 45.0},
	"elite":  {"cls": "elite",  "unlock": 120.0, "interval_hi": 75.0, "interval_lo": 32.0},
	"caster": {"cls": "caster", "unlock": 150.0, "interval_hi": 20.0, "interval_lo": 11.0},
}
