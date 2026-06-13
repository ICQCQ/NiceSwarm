class_name EnemyConfig
extends RefCounted
## Enemy archetype data — tune classes/tiers here. Used by main.gd as ENEMY_CLASSES.
## (See ENEMY_DESIGN.md for the field meanings and add-a-class checklist.)

# Enemy archetypes. Each class is an ordered list of tiers; a higher tier is a
# direct upgrade of the one before, and which tier spawns rises with time + level
# + difficulty (see _class_tier). Add a class or a tier here — `_build_type_registry`
# flattens them into stable network ids automatically.
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
		{"name": "Bomber", "hp0": 10.0, "hpk": 4.0, "spd": 110.0, "spdk": 1.0, "r": 15.0, "dmg": 1, "xp": 4, "col": Color(0.55, 0.12, 0.12), "shape": "circle", "caster": true, "pattern": 0, "cr": 115.0, "cd": 2, "cdt": 2.0, "keep": 280.0},
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
}
