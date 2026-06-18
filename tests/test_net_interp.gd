extends RefCounted
## NetInterp — time-based snapshot interpolation math. Pure + headless-verifiable
## (the *smoothness* needs a live link, but the bracketing/hold/teleport logic is
## deterministic and tested here).

func run(t) -> void:
	t.suite("net_interp")

	# Empty buffer returns the (zero) fallback, never crashes.
	var a := NetInterp.new()
	t.eq(a.sample(1000.0, 100.0), Vector2.ZERO, "empty buffer -> zero")

	# A single sample is held for any render time.
	var b := NetInterp.new()
	b.push(0.0, Vector2(5, 7))
	t.eq(b.sample(1000.0, 100.0), Vector2(5, 7), "single sample held")

	# Two samples, render time between them -> linear interpolation.
	var c := NetInterp.new()
	c.push(0.0, Vector2(0, 0))
	c.push(100.0, Vector2(100, 0))
	t.eq(c.sample(200.0, 150.0), Vector2(50, 0), "midpoint lerp (rt=50)")
	t.approx(c.sample(200.0, 180.0).x, 20.0, 0.01, "20% lerp (rt=20)")

	# Underrun (render time past the newest) holds the newest sample.
	t.eq(c.sample(300.0, 50.0), Vector2(100, 0), "underrun holds newest")
	# Render time before the oldest holds the oldest sample.
	t.eq(c.sample(100.0, 200.0), Vector2(0, 0), "pre-history holds oldest")

	# A jump beyond TELEPORT_DIST resets the buffer -> snaps (no slide across the map).
	var d := NetInterp.new()
	d.push(0.0, Vector2(0, 0))
	var far := Vector2(NetInterp.TELEPORT_DIST + 50.0, 0)
	d.push(10.0, far)
	t.eq(d.sample(10.0, 0.0), far, "teleport snaps to new spot")

	# The ring buffer is capped at MAX_SNAPS.
	var e := NetInterp.new()
	for i in 20:
		e.push(float(i), Vector2(i, 0))
	t.ok(e._ts.size() <= NetInterp.MAX_SNAPS, "buffer capped at MAX_SNAPS")
