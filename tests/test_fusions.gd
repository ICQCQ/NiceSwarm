extends RefCounted
## Unit tests for the fusion system: every unordered weapon pair must have a signature
## recipe (Fusions.info), the lookup must be order-independent, and Fusions.make must
## return a real WeaponBase for every pair.

const IDS := ["bolt", "orbit", "nova", "glaive", "lightning", "flame", "mines",
	"missiles", "laser", "frost", "gravity", "turret", "venom"]

func run(t) -> void:
	t.suite("fusions")

	var pairs := 0
	var covered := 0
	for i in IDS.size():
		for j in range(i + 1, IDS.size()):
			pairs += 1
			var a: String = IDS[i]
			var b: String = IDS[j]
			var info: Dictionary = Fusions.info(a, b)
			var info_rev: Dictionary = Fusions.info(b, a)
			t.ok(not info.is_empty(), "info(%s,%s) has a signature recipe" % [a, b])
			t.eq(info.get("name", ""), info_rev.get("name", "?"), "info order-independent for %s/%s" % [a, b])
			if not info.is_empty():
				covered += 1
				t.ne(info.get("name", ""), "", "recipe %s/%s has a name" % [a, b])
			var w = Fusions.make(a, b)
			t.ok(w != null, "make(%s,%s) returns a weapon" % [a, b])
			if w != null:
				t.ok(w is WeaponBase, "make(%s,%s) is a WeaponBase" % [a, b])
				w.free()

	t.eq(pairs, 78, "13 weapons -> 78 unordered pairs")
	t.eq(covered, 78, "all 78 pairs have a signature recipe")
