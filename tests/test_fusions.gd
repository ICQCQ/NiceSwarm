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

	# Merge eligibility: only same-kind merges — base+base (0+0 -> signature, tier 1) or
	# signature+signature (1+1 -> amalgam, tier 2). Amalgams (tier >=2) are TERMINAL.
	t.eq(Fusions.merged_tier(0, 0), 1, "base+base merges to tier 1 (signature)")
	t.eq(Fusions.merged_tier(1, 1), 2, "signature+signature merges to tier 2 (amalgam)")
	t.ok(Fusions.can_merge(0, 0), "base+base is mergeable")
	t.ok(Fusions.can_merge(1, 1), "signature+signature is mergeable (-> amalgam)")
	t.ok(not Fusions.can_merge(0, 1), "base+signature can't merge")
	t.ok(not Fusions.can_merge(1, 0), "signature+base can't merge")
	t.ok(not Fusions.can_merge(2, 1), "amalgam+signature can't merge")
	t.ok(not Fusions.can_merge(2, 2), "amalgam+amalgam can't merge (amalgam is terminal)")
	t.ok(not Fusions.can_merge(2, 0), "amalgam+base can't merge")
	# general invariant: mergeable iff same tier and tier <= 1
	for a in range(0, 4):
		for b in range(0, 4):
			t.eq(Fusions.can_merge(a, b), a == b and a <= 1, "can_merge(%d,%d) matches the same-kind rule" % [a, b])
