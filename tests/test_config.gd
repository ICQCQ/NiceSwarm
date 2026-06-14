extends RefCounted
## Unit tests for GameConfig — the central run/difficulty/spawn tuning consts.
## Guards against accidental edits that would silently break balance or perf.

func run(t) -> void:
	t.suite("config")

	# core run
	t.eq(GameConfig.WIN_TIME, 600.0, "WIN_TIME is 10 minutes")
	t.eq(GameConfig.MAX_WEAPONS, 5, "MAX_WEAPONS")
	t.eq(GameConfig.MAX_WEAPON_LEVEL, 3, "MAX_WEAPON_LEVEL")
	t.eq(GameConfig.MAX_CHOICES, 6, "MAX_CHOICES")
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
	t.gt(GameConfig.DIFF_WARMUP_SECS, 0.0, "warmup secs positive")

	# spawning
	t.ok(GameConfig.SPAWN_RING_MIN <= GameConfig.SPAWN_RING_MAX, "spawn ring min <= max")
	t.gt(GameConfig.SPAWN_SAFE_RADIUS, 0.0, "safe radius positive")
	t.ok(GameConfig.SPAWN_INTERVAL_END < GameConfig.SPAWN_INTERVAL_START, "spawn interval tightens over time")
	t.ok(GameConfig.SPAWN_REFILL_MULT > 0.0 and GameConfig.SPAWN_REFILL_MULT < 1.0, "refill mult in (0,1)")
	t.ge(GameConfig.SPAWN_DESIRED_BASE, 1.0, "desired base >= 1")

	# heat spike / bosses / bouncers
	t.gt(GameConfig.MID_GAME_TIME, 0.0, "MID_GAME_TIME positive")
	t.gt(GameConfig.HEAT_SPIKE_MAX, 0.0, "HEAT_SPIKE_MAX positive")
	t.gt(GameConfig.BOSS_KILL_BASE, 0, "BOSS_KILL_BASE positive")
	t.gt(GameConfig.BOSS_KILL_INTERVAL, 0, "BOSS_KILL_INTERVAL positive")
	t.gt(GameConfig.BOUNCER_UNLOCK, 0.0, "BOUNCER_UNLOCK positive")
