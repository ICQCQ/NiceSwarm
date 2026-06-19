class_name AfflictConfig
extends RefCounted
## Catalog of every Afflict in the game. Afflict is a category, not one effect: each
## entry below is a distinct, independently-tracked debuff (see AfflictTracker) and
## any number of them can be active on the same enemy or player at once — Purgatory
## mark and Disruptor are two separate afflicts, both can be active on the same
## enemy/player simultaneously, neither overwrites the other.
##
## `affinity` is the BASE `key -> multiplier` map this afflict inflicts at stat_mult=1
## (no stat scaling) — which keys it touches and their base strength is tuned here,
## in one place, rather than hardcoded at each apply_x() call site. Purgatory's
## `1.2` means "+20% damage taken, of every DMG_* type, by default."
## Adding a new afflict: pick an id, add it here (name/color/affinity), then a small
## apply_x() wrapper (see Enemy.apply_vuln / Player.apply_disrupt) feeds it into
## `afflicts.apply(id, duration, mods, AfflictConfig.DEFS[id].color)`.

const DEFS := {
	"purgatory": {
		"name": "Purgatory Mark",
		"color": Color(0.6, 0.25, 0.75),
		# uniform across every DMG_* type — a marked enemy takes 20% bonus damage no
		# matter what hits it, deepened by Power via deepened() (see Enemy.apply_vuln)
		"affinity": {Enemy.DMG_PHYS: 1.2, Enemy.DMG_FIRE: 1.2, Enemy.DMG_ICE: 1.2, Enemy.DMG_ENERGY: 1.2},
	},
	"disrupt": {
		"name": "Disruptor",
		"color": Color(0.7, 0.3, 1.0),
		"affinity": {"speed": 0.5},  # used directly — Disruptor's slow isn't stat-scaled
	},
	"hover": {
		"name": "Hover",
		"color": Color(0.55, 0.85, 1.0),
		"affinity": {},  # no stat multiplier — callers gate ground/puddle effects with afflicts.has("hover") directly
	},
}


## DEFS[id]'s base `affinity`, deepened toward its extreme by `stat_mult` (1.0 = the
## base value unchanged) — same deepening shape as Enemy.apply_slow's potency: the
## *bonus* over/under 1.0 scales with the stat, not the multiplier itself, so a
## stat_mult of 2.0 on a 1.2 base (a 20% bonus) gives 1.4 (a 40% bonus), never 2.4.
## For afflicts whose strength is computed per-application (a weapon's level/Power).
static func deepened(id: String, stat_mult: float) -> Dictionary:
	var out := {}
	for key in DEFS[id].affinity:
		var base: float = DEFS[id].affinity[key]
		out[key] = 1.0 + (base - 1.0) * stat_mult
	return out
