class_name WeaponConfig
extends RefCounted
## Base tuning for the 13 base weapons. Each weapon reads `WeaponConfig.BASE[weapon_id]`
## for its core numbers — tune damage / growth / cadence here.
##   dmg    = base damage at level 1
##   growth = per-level damage bonus (damage = dmg * (1 + growth*(level-1)))
##   cd     = recurring cooldown / tick / re-hit interval (×Haste at runtime)
## Spatial sizes, projectile counts, and per-weapon extras stay in each weapon_*.gd.

const BASE := {
	"bolt":      {"dmg": 2.0, "growth": 0.30, "cd": 0.8},
	"orbit":     {"dmg": 2.0, "growth": 0.40, "cd": 0.45},  # cd = per-enemy re-hit
	"nova":      {"dmg": 3.0, "growth": 0.50, "cd": 3.5},
	"glaive":    {"dmg": 2.5, "growth": 0.30, "cd": 1.6},
	"lightning": {"dmg": 2.0, "growth": 0.40, "cd": 2.2},
	"flame":     {"dmg": 0.6, "growth": 0.40, "cd": 0.15},  # cd = tick interval
	"mines":     {"dmg": 6.0, "growth": 0.50, "cd": 2.0},
	"missiles":  {"dmg": 3.0, "growth": 0.30, "cd": 2.4},
	"laser":     {"dmg": 1.2, "growth": 0.40, "cd": 0.3},   # cd = per-enemy re-hit
	"frost":     {"dmg": 1.5, "growth": 0.30, "cd": 1.8},
	"gravity":   {"dmg": 0.5, "growth": 0.50, "cd": 6.0},
	"turret":    {"dmg": 1.2, "growth": 0.40, "cd": 6.5},
	"venom":     {"dmg": 0.8, "growth": 0.40, "cd": 0.35},  # cd = puddle drop interval
	# Deployed turret fusions (turret + X, see Fusions._Sentry). Lv1 dmg ==
	# a Lv3 base "turret"'s damage, so fusing doesn't feel like a downgrade.
	"sentry":    {"dmg": 2.16, "growth": 0.40, "cd": 4.5},
}
