extends RefCounted
## Unit tests for EnemyConfig — the CLASSES roster + SPAWN_POOL / SPAWN_SPECIALS tables.
## Catches malformed tiers and spawn rows that reference non-existent classes, and
## verifies the gem-condensation red threshold can't be hit by a normal (non-boss) drop.

const REQUIRED := ["name", "hp0", "hpk", "spd", "r", "dmg", "xp", "col"]

func run(t) -> void:
	t.suite("enemies")

	# every class has at least one tier, and every tier carries the required fields
	for cls in EnemyConfig.CLASSES:
		var tiers = EnemyConfig.CLASSES[cls]
		t.ok(tiers is Array and tiers.size() >= 1, "class '%s' has >=1 tier" % cls)
		for ti in tiers.size():
			var d: Dictionary = tiers[ti]
			for key in REQUIRED:
				t.ok(d.has(key), "%s tier %d has '%s'" % [cls, ti, key])
			t.gt(d.get("hp0", 0.0), 0.0, "%s t%d hp0 > 0" % [cls, ti])
			t.gt(d.get("r", 0.0), 0.0, "%s t%d radius > 0" % [cls, ti])
			t.ge(d.get("xp", -1), 0, "%s t%d xp >= 0" % [cls, ti])

	# core classes the spawner/boss/bouncer systems rely on must exist
	for cls in ["brawler", "elite", "boss", "bouncer", "shard"]:
		t.ok(EnemyConfig.CLASSES.has(cls), "CLASSES has '%s'" % cls)

	# SPAWN_POOL rows: valid class, positive weight, non-negative unlock
	for row in EnemyConfig.SPAWN_POOL:
		t.ok(EnemyConfig.CLASSES.has(row.cls), "SPAWN_POOL cls '%s' exists" % row.cls)
		t.gt(row.weight, 0, "SPAWN_POOL '%s' weight > 0" % row.cls)
		t.ge(row.unlock, 0.0, "SPAWN_POOL '%s' unlock >= 0" % row.cls)

	# SPAWN_SPECIALS: valid class, non-negative unlock
	for id in EnemyConfig.SPAWN_SPECIALS:
		var s: Dictionary = EnemyConfig.SPAWN_SPECIALS[id]
		t.ok(EnemyConfig.CLASSES.has(s.cls), "SPAWN_SPECIALS '%s' cls '%s' exists" % [id, s.cls])
		t.ge(s.get("unlock", 0.0), 0.0, "SPAWN_SPECIALS '%s' unlock >= 0" % id)

	# gem-cap invariant: no NORMAL (non-boss) enemy drops enough XP to false-read as a
	# condensed (red) gem; bosses do. Protects System 1's red threshold.
	var max_normal_xp := 0
	var min_boss_xp := 1 << 30
	for cls in EnemyConfig.CLASSES:
		for d in EnemyConfig.CLASSES[cls]:
			var xp: int = d.get("xp", 0)
			if cls == "boss":
				min_boss_xp = mini(min_boss_xp, xp)
			else:
				max_normal_xp = maxi(max_normal_xp, xp)
	t.ok(max_normal_xp < GameConfig.GEM_CONDENSED_THRESHOLD,
		"max non-boss xp (%d) < red threshold (%d)" % [max_normal_xp, GameConfig.GEM_CONDENSED_THRESHOLD])
	t.ge(min_boss_xp, GameConfig.GEM_CONDENSED_THRESHOLD, "boss xp >= red threshold")
