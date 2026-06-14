extends RefCounted
## Unit tests for the three-band XP curve (GameConfig.xp_for_level) — base, monotonicity,
## the steepening shape, band boundaries, and xp-rate scaling.

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

	# per-band slope equals the configured step, and the curve steepens
	var early_slope := GameConfig.xp_for_level(5, 1.0) - GameConfig.xp_for_level(4, 1.0)
	var mid_slope := GameConfig.xp_for_level(20, 1.0) - GameConfig.xp_for_level(19, 1.0)
	var late_slope := GameConfig.xp_for_level(40, 1.0) - GameConfig.xp_for_level(39, 1.0)
	t.eq(early_slope, GameConfig.XP_STEP_EARLY, "early slope == XP_STEP_EARLY")
	t.eq(mid_slope, GameConfig.XP_STEP_MID, "mid slope == XP_STEP_MID")
	t.eq(late_slope, GameConfig.XP_STEP_LATE, "late slope == XP_STEP_LATE")
	t.ok(early_slope <= mid_slope and mid_slope <= late_slope, "curve steepens (early<=mid<=late)")

	# band boundaries land where configured
	t.eq(GameConfig.xp_for_level(GameConfig.XP_BAND_EARLY + 1, 1.0) - GameConfig.xp_for_level(GameConfig.XP_BAND_EARLY, 1.0),
		GameConfig.XP_STEP_MID, "switches to mid step just past XP_BAND_EARLY")
	t.eq(GameConfig.xp_for_level(GameConfig.XP_BAND_MID + 1, 1.0) - GameConfig.xp_for_level(GameConfig.XP_BAND_MID, 1.0),
		GameConfig.XP_STEP_LATE, "switches to late step just past XP_BAND_MID")

	# xp rate divides the requirement; never below 1
	t.eq(GameConfig.xp_for_level(20, 2.0), int(round(GameConfig.xp_for_level(20, 1.0) / 2.0)), "xp_rate 2x halves the need")
	t.ge(GameConfig.xp_for_level(1, 99.0), 1, "need never drops below 1 even at huge xp_rate")
