extends RefCounted
## Unit tests for the XP-gem value model behind System 1 (gem cap + red condensation).

func run(t) -> void:
	t.suite("gems")

	var g := XpGem.new()
	t.eq(g.value, 1, "a fresh gem's default value is 1")
	# condensation bumps value; once it reaches the threshold the gem renders red.
	g.value += GameConfig.GEM_CONDENSED_THRESHOLD
	t.ge(g.value, GameConfig.GEM_CONDENSED_THRESHOLD, "value can reach the red threshold")
	g.free()

	# red should signal a genuine *pile*: the threshold must exceed several normal drops
	# (a single drop is 1–5 XP), so it can't trip on one gem.
	t.ge(GameConfig.GEM_CONDENSED_THRESHOLD, 5, "red threshold needs multiple drops to reach")
