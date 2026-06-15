extends RefCounted
## Unit tests for the exponential XP curve (GameConfig.xp_for_level): base cost,
## monotonicity, geometric (compounding) growth, and xp-rate scaling.

func run(t) -> void:
	t.suite("xp_curve")

	# base cost
	t.eq(GameConfig.xp_for_level(1, 1.0), GameConfig.XP_BASE, "L1 costs XP_BASE")

	# monotonic non-decreasing across the whole range
	var mono := true
	var prev := 0
	for L in range(1, 70):
		var need := GameConfig.xp_for_level(L, 1.0)
		if need < prev:
			mono = false
		prev = need
	t.ok(mono, "xp curve is monotonic non-decreasing")

	# exponential = convex: the per-level increment keeps GROWING (unlike a linear curve)
	var slope_early := GameConfig.xp_for_level(11, 1.0) - GameConfig.xp_for_level(10, 1.0)
	var slope_late := GameConfig.xp_for_level(41, 1.0) - GameConfig.xp_for_level(40, 1.0)
	t.gt(slope_late, slope_early, "curve steepens — late increment >> early increment")

	# closed form matches the geometric definition: need = XP_BASE * XP_GROWTH^(lvl-1)
	t.eq(GameConfig.xp_for_level(20, 1.0), int(round(GameConfig.XP_BASE * pow(GameConfig.XP_GROWTH, 19))),
		"matches XP_BASE * XP_GROWTH^(lvl-1)")

	# at high levels (rounding negligible) consecutive costs grow by ~XP_GROWTH
	var ratio := float(GameConfig.xp_for_level(51, 1.0)) / float(GameConfig.xp_for_level(50, 1.0))
	t.ok(absf(ratio - GameConfig.XP_GROWTH) < 0.02, "consecutive costs grow by ~XP_GROWTH late")

	# xp rate divides the requirement (higher rate = cheaper); never below 1
	t.lt(GameConfig.xp_for_level(20, 2.0), GameConfig.xp_for_level(20, 1.0), "higher xp_rate lowers the cost")
	t.ge(GameConfig.xp_for_level(1, 99.0), 1, "need never drops below 1 even at huge xp_rate")
