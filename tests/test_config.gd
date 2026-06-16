extends RefCounted
## Unit tests for GameConfig — the central run/difficulty/spawn tuning consts.
## Guards against accidental edits that would silently break balance or perf.

func run(t) -> void:
	t.suite("config")

	# core run
	t.eq(GameConfig.WIN_TIME, 600.0, "WIN_TIME is 10 minutes")
	t.eq(GameConfig.MAX_WEAPONS, 5, "MAX_WEAPONS")
	t.eq(GameConfig.MAX_WEAPON_LEVEL, 7, "MAX_WEAPON_LEVEL")
	t.eq(GameConfig.MAX_FUSION_TIER, 3, "MAX_FUSION_TIER")
	t.gt(GameConfig.WEAPON_LEVEL_POWER, 0.0, "WEAPON_LEVEL_POWER positive (weapons scale with party level)")
	t.eq(GameConfig.MAX_CHOICES, 6, "MAX_CHOICES")
	t.ok(GameConfig.XP_GAIN_MULT > 0.0 and GameConfig.XP_GAIN_MULT <= 1.0, "XP_GAIN_MULT in (0,1]")

	# player stat-upgrade caps
	t.eq(GameConfig.STAT_CAP_POWER, 6.0, "STAT_CAP_POWER")
	t.eq(GameConfig.STAT_CAP_AREA, 2.0, "STAT_CAP_AREA")
	t.eq(GameConfig.STAT_CAP_DURATION, 2.5, "STAT_CAP_DURATION")
	t.eq(GameConfig.STAT_CAP_MAX_HP, 15, "STAT_CAP_MAX_HP")
	t.ok(GameConfig.STAT_CAP_RATE > 0.0 and GameConfig.STAT_CAP_RATE < 1.0, "STAT_CAP_RATE is a sub-1 rate floor (faster)")
	t.gt(GameConfig.STAT_CAP_SPEED, 220.0, "STAT_CAP_SPEED above base move speed")
	t.gt(GameConfig.STAT_CAP_MAGNET, 90.0, "STAT_CAP_MAGNET above base pickup range")
	t.eq(GameConfig.ENEMY_CAP, 220, "ENEMY_CAP")
	t.eq(GameConfig.NET_PORT, 24565, "NET_PORT")
	t.gt(GameConfig.TELEGRAPH_WARN, 0.0, "TELEGRAPH_WARN positive")
	t.ok(GameConfig.ARENA.size.x > 0.0 and GameConfig.ARENA.size.y > 0.0, "ARENA has positive size")

	# gem cap (System 1)
	t.eq(GameConfig.MAX_GEMS, 500, "MAX_GEMS")
	t.gt(GameConfig.GEM_CONDENSED_THRESHOLD, 0, "GEM_CONDENSED_THRESHOLD positive")

	# difficulty climb
	t.gt(GameConfig.DIFF_BASE, 0.0, "DIFF_BASE positive")
	t.ge(GameConfig.DIFF_HEAT, 0.0, "DIFF_HEAT non-negative")
	t.ge(GameConfig.DIFF_LEVEL, 0.0, "DIFF_LEVEL non-negative")
	t.ok(GameConfig.DIFF_WARMUP_FLOOR > 0.0 and GameConfig.DIFF_WARMUP_FLOOR <= 1.0, "warmup floor in (0,1]")
	t.gt(GameConfig.DIFF_WARMUP_PROGRESS, 0.0, "warmup progress positive")

	# spawning
	t.ok(GameConfig.SPAWN_RING_MIN <= GameConfig.SPAWN_RING_MAX, "spawn ring min <= max")
	t.gt(GameConfig.SPAWN_SAFE_RADIUS, 0.0, "safe radius positive")
	t.ok(GameConfig.SPAWN_INTERVAL_END < GameConfig.SPAWN_INTERVAL_START, "spawn interval tightens over time")
	t.ok(GameConfig.SPAWN_REFILL_MULT > 0.0 and GameConfig.SPAWN_REFILL_MULT < 1.0, "refill mult in (0,1)")
	t.ge(GameConfig.SPAWN_DESIRED_BASE, 1.0, "desired base >= 1")

	# heat spike / bosses / bouncers
	t.gt(GameConfig.MID_GAME_PROGRESS, 0.0, "MID_GAME_PROGRESS positive")
	t.gt(GameConfig.HEAT_SPIKE_MAX, 0.0, "HEAT_SPIKE_MAX positive")
	t.gt(GameConfig.BOSS_KILL_BASE, 0, "BOSS_KILL_BASE positive")
	t.gt(GameConfig.BOSS_KILL_INTERVAL, 0, "BOSS_KILL_INTERVAL positive")
	t.gt(GameConfig.BOUNCER_UNLOCK_PROGRESS, 0.0, "BOUNCER_UNLOCK_PROGRESS positive")

	# enemy hp / cc scaling knobs
	t.gt(GameConfig.ENEMY_HP_PER_LEVEL, 0.0, "ENEMY_HP_PER_LEVEL positive")
	t.ge(GameConfig.CC_IMMUNE_TIER, 1, "CC_IMMUNE_TIER >= 1")

	# DPS-responsive boss hp (GameConfig.boss_hp)
	t.gt(GameConfig.BOSS_DPS_WINDOW, 0.0, "BOSS_DPS_WINDOW positive")
	t.gt(GameConfig.BOSS_FIGHT_SECONDS, 0.0, "BOSS_FIGHT_SECONDS positive")
	# low DPS -> the tier floor dominates; solo level 1 -> no level/count multipliers
	t.eq(GameConfig.boss_hp(1000.0, 0.0, 1, 1), 1000.0, "boss_hp floors at tier base when dps is 0")
	# high DPS -> hp tracks recent_dps * BOSS_FIGHT_SECONDS
	t.eq(GameConfig.boss_hp(100.0, 500.0, 1, 1), 500.0 * GameConfig.BOSS_FIGHT_SECONDS, "boss_hp scales with recent dps")
	# party level and player count both raise it
	t.gt(GameConfig.boss_hp(1000.0, 0.0, 20, 1), 1000.0, "boss_hp rises with party level")
	t.gt(GameConfig.boss_hp(1000.0, 0.0, 1, 4), GameConfig.boss_hp(1000.0, 0.0, 1, 1), "boss_hp rises with player count")
