extends RefCounted
## Unit tests for EnemySpawner's pure math (type registry, warmup brake, class_tier
## bounds, heat/diff host reads, reset) driven by a minimal mock `main` node so no
## scene/world is required.

class MockMain extends Node:
	var elapsed := 0.0
	var level := 1
	var peer_ids := [1]
	var enemies_by_id := {}
	var world: Node = null
	func is_host() -> bool:
		return true


func run(t) -> void:
	t.suite("spawner")
	var sp := EnemySpawner.new()
	var mock := MockMain.new()
	sp.main = mock

	# --- type registry: one stable index per (class, tier) ---
	sp.build_type_registry()
	t.gt(sp.types.size(), 0, "type registry built")
	t.ok(sp.type_id.has("brawler:0"), "registry indexes brawler:0")
	var total_tiers := 0
	for cls in EnemyConfig.CLASSES:
		total_tiers += EnemyConfig.CLASSES[cls].size()
	t.eq(sp.types.size(), total_tiers, "one registry entry per (class,tier)")
	var consistent := true
	for key in sp.type_id:
		var idx: int = sp.type_id[key]
		if "%s:%d" % [sp.types[idx].cls, sp.types[idx].tier] != key:
			consistent = false
	t.ok(consistent, "type_id <-> types stay consistent")

	# --- warmup brake ---
	mock.elapsed = 0.0
	t.approx(sp.warmup(), GameConfig.DIFF_WARMUP_FLOOR, 0.001, "warmup at t=0 is the floor")
	mock.elapsed = GameConfig.DIFF_WARMUP_SECS * 2.0
	t.approx(sp.warmup(), 1.0, 0.001, "warmup saturates to 1.0")

	# --- class_tier always in [0, tiers-1] ---
	sp.pace = 0.0
	t.eq(sp.class_tier("brawler"), 0, "class_tier 0 at pace 0")
	sp.pace = 99.0
	var n: int = EnemyConfig.CLASSES["brawler"].size()
	var in_range := true
	for i in 50:
		var tier := sp.class_tier("brawler")
		if tier < 0 or tier >= n:
			in_range = false
	t.ok(in_range, "class_tier stays within [0, tiers-1] at high pace")

	# --- heat()/diff() read host values ---
	sp.heat_cur = 0.42
	sp.difficulty = 3.5
	t.approx(sp.heat(), 0.42, 0.001, "heat() returns host heat_cur")
	t.approx(sp.diff(), 3.5, 0.001, "diff() returns host difficulty")

	# --- reset() restores the baseline ---
	sp.reset()
	t.eq(sp.pace, 0.0, "reset zeroes pace")
	t.eq(sp.difficulty, 0.0, "reset zeroes difficulty")
	t.eq(sp.boss_next_kill, GameConfig.BOSS_KILL_BASE, "reset arms the first boss")

	# --- wave rhythm (pure function of elapsed) ---
	t.eq(GameConfig.WAVES.size(), 10, "10 wave minutes")
	mock.elapsed = 0.0
	t.approx(sp.wave_intensity(), GameConfig.WAVES[0][0], 0.001, "intensity at min 0")
	t.approx(sp.wave_pop_mult(), GameConfig.WAVES[0][1], 0.001, "pop_mult at min 0")
	mock.elapsed = 120.0
	t.approx(sp.wave_intensity(), GameConfig.WAVES[2][0], 0.001, "intensity at min 2 peak")
	mock.elapsed = 180.0
	t.ok(sp.wave_intensity() < 1.0, "min 3 is a valley (intensity < 1)")
	mock.elapsed = 150.0  # halfway between min 2 and min 3 -> lerp
	t.approx(sp.wave_intensity(), lerpf(GameConfig.WAVES[2][0], GameConfig.WAVES[3][0], 0.5), 0.001, "intensity lerps between minutes")
	mock.elapsed = 9999.0
	t.approx(sp.wave_intensity(), GameConfig.WAVES[GameConfig.WAVES.size() - 1][0], 0.001, "clamps to last minute past the table")
	var all_pos := true
	for entry in GameConfig.WAVES:
		if entry[0] <= 0.0 or entry[1] <= 0.0:
			all_pos = false
	t.ok(all_pos, "all wave entries are positive")

	sp.free()
	mock.free()
