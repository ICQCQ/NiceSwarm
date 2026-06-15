extends RefCounted
## Unit tests for the exponential XP curve (GameConfig.xp_for_level): base cost,
## monotonicity, geometric (compounding) growth, and xp-rate scaling.

func run(t) -> void:
	t.suite("xp_curve")

	# first level-up is a flat, cheap cost (snappy opening), independent of xp_rate
	t.eq(GameConfig.xp_for_level(1, 1.0), GameConfig.XP_FIRST_LEVEL, "L1 costs XP_FIRST_LEVEL")
	t.eq(GameConfig.xp_for_level(1, 2.0), GameConfig.XP_FIRST_LEVEL, "L1 flat cost ignores xp_rate")
	# level 2 onward follows the geometric curve from XP_BASE
	t.eq(GameConfig.xp_for_level(2, 1.0), int(round(GameConfig.XP_BASE * GameConfig.XP_GROWTH)), "L2 follows the curve")

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
	t.gt(GameConfig.xp_for_level(20, 1.0), GameConfig.xp_for_level(20, 2.0), "higher xp_rate lowers the cost")
	t.ge(GameConfig.xp_for_level(1, 99.0), 1, "need never drops below 1 even at huge xp_rate")

	t.suite("xp_early_bonus")

	# the bonus multiplies collected XP for the first EARLY_XP_BONUS_LEVELS levels
	t.eq(GameConfig.xp_gain(3, 1), 3 * GameConfig.EARLY_XP_BONUS_MULT, "level 1 gem is multiplied")
	t.eq(GameConfig.xp_gain(3, GameConfig.EARLY_XP_BONUS_LEVELS),
		3 * GameConfig.EARLY_XP_BONUS_MULT, "last bonus level is still multiplied (inclusive)")

	# the bonus stops the moment the player passes the window
	t.eq(GameConfig.xp_gain(3, GameConfig.EARLY_XP_BONUS_LEVELS + 1), 3, "first level past the window is raw")
	t.eq(GameConfig.xp_gain(7, 20), 7, "deep into the run XP is unmultiplied")

	# preserves the zero/identity edges
	t.eq(GameConfig.xp_gain(0, 1), 0, "zero-value gem stays zero even in the bonus window")
