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

	# slow buff: every slow source funnels through Enemy.apply_slow, which deepens the
	# incoming speed factor by SLOW_POTENCY and clamps it to SLOW_FLOOR_MULT (the "really
	# slow" buff). Test the real function on a bare Enemy (apply_slow needs no tree).
	var e := Enemy.new()
	e.apply_slow(0.7, 1.0)  # mild slow: deepened but still above the floor
	t.approx(e.slow_mult, 1.0 - 0.3 * GameConfig.SLOW_POTENCY, 0.001, "slow deepened by potency")
	t.eq(e.slow_timer, 1.0, "slow timer set")
	e.apply_slow(0.45, 0.5)  # strong slow: deepen drops below the floor -> clamps
	t.eq(e.slow_mult, GameConfig.SLOW_FLOOR_MULT, "deep slow clamps to SLOW_FLOOR_MULT")
	e.cc_immune = true
	e.slow_mult = 1.0
	e.apply_slow(0.5, 1.0)
	t.eq(e.slow_mult, 1.0, "cc_immune enemies can't be slowed")
	e.free()

	# DamageAffinity: weak/strong/immune multipliers, several types tracked at once,
	# and mutable at runtime (not baked in at spawn).
	var aff := DamageAffinity.new()
	t.eq(aff.get_mult(Enemy.DMG_FIRE), 1.0, "unset type defaults to 1.0")
	aff.set_mult(Enemy.DMG_FIRE, 1.5)
	aff.set_mult(Enemy.DMG_ICE, 0.5)
	aff.set_mult(Enemy.DMG_ENERGY, 0.0)
	t.eq(aff.get_mult(Enemy.DMG_FIRE), 1.5, "weak type set")
	t.eq(aff.get_mult(Enemy.DMG_ICE), 0.5, "strong/resist type set independently")
	t.ok(aff.is_immune(Enemy.DMG_ENERGY), "0.0 mult reads as immune")
	t.ok(not aff.is_immune(Enemy.DMG_FIRE), "weak type is not immune")
	aff.set_mult(Enemy.DMG_FIRE, 1.0)  # runtime mutation back to default prunes the entry
	t.ok(not aff.mults.has(Enemy.DMG_FIRE), "re-setting to 1.0 clears the entry")
	aff.clear(Enemy.DMG_ICE)
	t.eq(aff.get_mult(Enemy.DMG_ICE), 1.0, "clear() reverts to default")

	# wired into Enemy.take_hit: weak/strong/immune apply before resist, multiple at once
	var parent := Node.new()  # take_hit spawns a floating damage number via get_parent()
	var w := Enemy.new()
	parent.add_child(w)
	w.hp = 100.0
	w.dmg_affinity.set_mult(Enemy.DMG_FIRE, 1.5)
	w.take_hit(10.0, null, Enemy.DMG_FIRE)
	t.approx(w.hp, 85.0, 0.001, "weak type applies its multiplier (10 * 1.5 = 15 dmg)")
	w.take_hit(10.0, null, Enemy.DMG_PHYS)
	t.approx(w.hp, 75.0, 0.001, "untagged type is unaffected by the FIRE entry")
	w.dmg_affinity.set_mult(Enemy.DMG_ICE, 0.0)
	w.take_hit(10.0, null, Enemy.DMG_ICE)
	t.approx(w.hp, 75.0, 0.001, "0.0 mult takes zero damage")
	w.dmg_affinity.set_mult(Enemy.DMG_ENERGY, 0.5)
	w.take_hit(10.0, null, Enemy.DMG_ENERGY)
	t.approx(w.hp, 70.0, 0.001, "ICE immunity and ENERGY resist coexist independently (10 * 0.5 = 5 dmg)")
	w.resist = 0.5
	w.take_hit(10.0, null, Enemy.DMG_FIRE)
	t.approx(w.hp, 62.5, 0.001, "type mult applies before armor resist (10 * 1.5 * 0.5 = 7.5 dmg)")
	parent.free()

	# apply_vuln (Purgatory mark) rides AfflictTracker: a uniform extra-damage mark on
	# every DMG_* at once (base +20%, see AfflictConfig), deepened by stat_mult, and
	# the multi-source "longest remaining wins" stacking rule.
	var vparent := Node.new()
	var v := Enemy.new()
	vparent.add_child(v)
	v.hp = 100.0
	v.apply_vuln(1.0, 5.0)  # stat_mult 1.0 = the base bonus unchanged -> 1.2x
	t.ok(v.afflicts.has("purgatory"), "apply_vuln activates the 'purgatory' afflict")
	v.take_hit(10.0, null, Enemy.DMG_ICE)
	t.approx(v.hp, 88.0, 0.001, "vuln's bonus applies uniformly to every DMG_* type (10 * 1.2 = 12)")
	v.apply_vuln(5.0, 1.0)  # a much stronger mark, but from another source with a shorter duration — dropped entirely
	v.take_hit(10.0, null, Enemy.DMG_PHYS)
	t.approx(v.hp, 76.0, 0.001, "the shorter re-application never took effect — still 1.2x")
	v.apply_vuln(2.5, 999.0)  # stat_mult 2.5 -> 1.0 + 0.2*2.5 = 1.5x, with a much longer duration — wins outright
	v.take_hit(10.0, null, Enemy.DMG_PHYS)
	t.approx(v.hp, 61.0, 0.001, "a longer-duration re-application replaces both mult and timer (10 * 1.5 = 15)")

	# Afflict is a category, not a single effect: an enemy can carry several distinct
	# afflicts at once, each independently tracked, all contributing to the same hit.
	v.afflicts.apply("scorched", 10.0, {Enemy.DMG_FIRE: 1.5})
	t.ok(v.afflicts.has("purgatory") and v.afflicts.has("scorched"), "two distinct afflicts coexist")
	v.take_hit(10.0, null, Enemy.DMG_FIRE)
	t.approx(v.hp, 38.5, 0.001, "both afflicts' mults apply together (10 * 1.5 purgatory * 1.5 scorched = 22.5)")
	v.afflicts.remove("scorched")  # only the unrelated afflict drops out
	t.ok(v.afflicts.has("purgatory") and not v.afflicts.has("scorched"), "removing one leaves the other untouched")
	vparent.free()
