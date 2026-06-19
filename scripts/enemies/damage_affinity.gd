class_name DamageAffinity
extends RefCounted
## Per-enemy table of DMG_* type -> damage multiplier (1.0 = normal, 0.0 = immune,
## >1.0 = weak/vulnerable, <1.0 = resistant). Holds any number of types at once —
## an enemy can be weak to FIRE and resistant to ICE simultaneously — and is freely
## mutable at runtime, so a status effect, debuff, or boss mechanic (e.g. the
## Harbinger's rotating immunity) can retag matchups mid-fight without Enemy itself
## needing new fields per case.

var mults: Dictionary = {}  # int (DMG_*) -> float, only non-default entries stored


func get_mult(dtype: int) -> float:
	return mults.get(dtype, 1.0)


func set_mult(dtype: int, mult: float) -> void:
	if is_equal_approx(mult, 1.0):
		mults.erase(dtype)  # 1.0 is the implicit default — don't bloat the table
	else:
		mults[dtype] = mult


func clear(dtype: int) -> void:
	mults.erase(dtype)


func clear_all() -> void:
	mults.clear()


func is_immune(dtype: int) -> bool:
	return get_mult(dtype) <= 0.0
