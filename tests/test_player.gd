extends RefCounted
## Unit tests for Player methods that don't need a live scene tree (mirrors how
## test_enemies.gd exercises Enemy.apply_slow/take_hit directly). Movement/_draw/
## _process are scene-bound and covered by the headless integration hooks instead
## (see run_tests.gd's Scope note) — this only covers apply_disrupt's AfflictTracker wiring.

func run(t) -> void:
	t.suite("player")

	var p := Player.new()
	t.ok(not p.afflicts.has("disrupt"), "starts undisrupted")
	p.apply_disrupt(2.0)
	t.ok(p.afflicts.has("disrupt"), "apply_disrupt activates the 'disrupt' afflict")
	t.eq(p.afflicts.mult("speed"), 0.5, "disrupt halves the speed mult")

	p.apply_disrupt(0.2)  # a much shorter re-application from another source — dropped
	t.eq(p.afflicts.mult("speed"), 0.5, "shorter re-application doesn't shorten or weaken it")

	p.apply_disrupt(10.0)  # longer duration — replaces it outright
	p.afflicts.tick(5.0)
	t.ok(p.afflicts.has("disrupt"), "longer re-application's extended duration takes effect")
	p.free()

	# dashing/invuln shrugs off a fresh disrupt entirely
	var q := Player.new()
	q.invuln = 0.5
	q.apply_disrupt(2.0)
	t.ok(not q.afflicts.has("disrupt"), "invulnerable players ignore disrupt")
	q.free()
