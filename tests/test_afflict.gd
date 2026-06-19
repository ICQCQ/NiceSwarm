extends RefCounted
## Unit tests for AfflictTracker (the generic named/timed debuff tracker shared by Enemy
## and Player) and AfflictConfig (the catalog of every distinct afflict in the game —
## Afflict is a category with many members, not a single effect).

func run(t) -> void:
	t.suite("afflict")

	var a := AfflictTracker.new()
	t.ok(a.is_empty(), "starts empty")
	t.eq(a.mult("speed"), 1.0, "unset key defaults to 1.0")

	# basic apply + mult
	a.apply("slow", 2.0, {"speed": 0.5})
	t.ok(a.has("slow"), "apply() activates the id")
	t.eq(a.mult("speed"), 0.5, "mult() reads the applied modifier")

	# re-applying the SAME id with a SHORTER duration is rejected outright — both the
	# duration and the (weaker) modifier are dropped, not just the timer
	a.apply("slow", 0.5, {"speed": 0.9})
	t.eq(a.mult("speed"), 0.5, "shorter re-application is ignored (modifier unchanged)")

	# re-applying with a LONGER duration replaces both duration and modifier
	a.apply("slow", 5.0, {"speed": 0.25})
	t.eq(a.mult("speed"), 0.25, "longer re-application replaces the modifier")

	# multiple distinct ids stack multiplicatively, independent of each other
	a.apply("weaken", 3.0, {"speed": 0.5})
	t.approx(a.mult("speed"), 0.125, 0.0001, "two active ids multiply (0.25 * 0.5)")

	# expiry via tick()
	a.tick(2.9)  # "weaken" (3.0s) still alive, "slow" (5.0s, refreshed) still alive
	t.ok(a.has("weaken"), "not yet expired")
	a.tick(0.2)  # weaken's remaining ~0.1s consumed
	t.ok(not a.has("weaken"), "expired afflict is pruned")
	t.eq(a.mult("speed"), 0.25, "mult() reflects pruned state (only slow left)")

	# DMG_* int keys and player-style String keys never collide on the same tracker
	var b := AfflictTracker.new()
	b.apply("expose", 4.0, {Enemy.DMG_FIRE: 1.5, Enemy.DMG_ICE: 0.5})
	t.eq(b.mult(Enemy.DMG_FIRE), 1.5, "int DMG_* key")
	t.eq(b.mult(Enemy.DMG_ICE), 0.5, "a second int key on the same afflict")
	t.eq(b.mult(Enemy.DMG_ENERGY), 1.0, "an untagged type on the afflict stays default")
	b.apply("disrupt", 4.0, {"speed": 0.5})
	t.eq(b.mult("speed"), 0.5, "String key coexists with int keys on the same tracker")
	t.eq(b.mult(Enemy.DMG_FIRE), 1.5, "...without disturbing the int-keyed afflict")
	b.remove("expose")
	t.ok(not b.has("expose") and b.has("disrupt"), "remove() ends one afflict without touching others")

	# AfflictConfig: the catalog of every afflict in the game — Purgatory mark is one
	# entry among (eventually) many, not a special case baked into the tracker itself.
	t.ok(AfflictConfig.DEFS.has("purgatory"), "catalog lists Purgatory mark")
	t.ok(AfflictConfig.DEFS.has("disrupt"), "catalog lists Disruptor")
	for id in AfflictConfig.DEFS:
		var def: Dictionary = AfflictConfig.DEFS[id]
		t.ok(def.has("name") and def.has("color") and def.has("affinity"),
			"afflict '%s' has a name, color, and base affinity" % id)

	# the base affinity is tunable in DEFS directly: Disruptor's slow is fixed...
	t.eq(AfflictConfig.DEFS.disrupt.affinity.get("speed"), 0.5, "Disruptor's base affinity")
	# Purgatory's base is +20% damage taken, of every DMG_* type, by default...
	t.eq(AfflictConfig.DEFS.purgatory.affinity[Enemy.DMG_FIRE], 1.2, "Purgatory's base is a 20% bonus")
	# ...and deepens with a stat (weapon level/Power) via deepened(): the *bonus* over
	# 1.0 scales with stat_mult, not the multiplier itself (same shape as apply_slow's
	# potency deepening) — a stat_mult of 2.0 on a 20% bonus gives a 40% bonus, not 140%.
	t.eq(AfflictConfig.deepened("purgatory", 1.0)[Enemy.DMG_FIRE], 1.2, "stat_mult=1 leaves the base unchanged")
	t.approx(AfflictConfig.deepened("purgatory", 2.0)[Enemy.DMG_FIRE], 1.4, 0.0001, "stat_mult=2 doubles the BONUS (0.2 -> 0.4), not the multiplier")
	t.eq(AfflictConfig.deepened("purgatory", 0.0)[Enemy.DMG_ICE], 1.0, "stat_mult=0 fully negates the bonus")
	t.eq(AfflictConfig.deepened("purgatory", 1.0)[Enemy.DMG_ICE], AfflictConfig.deepened("purgatory", 1.0)[Enemy.DMG_FIRE],
		"uniform across every key in the base affinity")
