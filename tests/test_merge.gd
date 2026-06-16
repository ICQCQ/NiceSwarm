extends RefCounted
## Reproduction/regression for DEEP fusion: build TWO tier-2 weapons and amalgamate
## them into a tier-3, asserting the node structure (component count, tiers, ids,
## ownership) survives. merge_weapons only restructures nodes (no Main), so a bare
## off-tree Player exercises the real path. Covers the "2 tier-2 weapons: only one
## works / the amalgam doesn't work" bug report.

## Every leaf component must be able to walk up to the owning Player — this is
## exactly how WeaponBase._ready resolves `player`, and a leaf that can't reach it
## silently never fires ("only one works"). Recurses through nested WeaponFused.
func _all_leaves_reach_player(node, p) -> bool:
	for c in node.get_children():
		if c is WeaponFused:
			if not _all_leaves_reach_player(c, p):
				return false
			continue
		if not (c is WeaponBase):
			continue
		var n = c.get_parent()
		while n != null and not (n is Player):
			n = n.get_parent()
		if n != p:
			return false
	return true


func _fuse(p, id_a: String, id_b: String):
	# Max both inputs (the [MERGE] pool only offers maxed weapons) and fuse them;
	# merge_weapons always appends the result last.
	p.get_weapon(id_a).level = GameConfig.MAX_WEAPON_LEVEL
	p.get_weapon(id_b).level = GameConfig.MAX_WEAPON_LEVEL
	p.merge_weapons(id_a, id_b)
	return p.weapons[p.weapons.size() - 1]


func run(t) -> void:
	t.suite("merge")
	var p := Player.new()
	for wid in ["bolt", "nova", "frost", "lightning", "glaive", "venom", "laser", "orbit"]:
		p.add_weapon(wid)
	t.eq(p.weapons.size(), 8, "8 base weapons added")

	# --- tier-2 #1 = (bolt+nova) merged with (frost+lightning) ---
	var a1 = _fuse(p, "bolt", "nova")             # tier-1 signature fusion
	var b1 = _fuse(p, "frost", "lightning")       # tier-1 signature fusion
	t.eq(a1.tier, 1, "bolt+nova is tier 1")
	t.eq(b1.tier, 1, "frost+lightning is tier 1")
	var t2a = _fuse(p, a1.weapon_id, b1.weapon_id)
	t.eq(t2a.tier, 2, "tier-2 #1 has tier 2")
	t.eq(t2a.get_child_count(), 2, "tier-2 #1 holds its 2 components")

	# --- tier-2 #2 = (glaive+venom) merged with (laser+orbit) ---
	var c1 = _fuse(p, "glaive", "venom")
	var d1 = _fuse(p, "laser", "orbit")
	var t2b = _fuse(p, c1.weapon_id, d1.weapon_id)
	t.eq(t2b.tier, 2, "tier-2 #2 has tier 2")
	t.eq(t2b.get_child_count(), 2, "tier-2 #2 holds its 2 components")

	# both tier-2 weapons must coexist as distinct, owned, processing weapons
	t.eq(p.weapons.size(), 2, "exactly the two tier-2 weapons remain")
	t.ne(t2a.weapon_id, t2b.weapon_id, "the two tier-2 weapons have distinct ids")
	t.ok(p.get_weapon(t2a.weapon_id) != null, "tier-2 #1 is owned")
	t.ok(p.get_weapon(t2b.weapon_id) != null, "tier-2 #2 is owned")
	# every leaf of BOTH tier-2 weapons must resolve the Player, or it never fires
	t.ok(_all_leaves_reach_player(t2a, p), "tier-2 #1 components all reach the player (fire)")
	t.ok(_all_leaves_reach_player(t2b, p), "tier-2 #2 components all reach the player (fire)")

	# --- amalgam: two tier-2 -> one tier-3 holding all 4 leaf components ---
	t.ok(Fusions.can_merge(t2a.tier, t2b.tier), "two tier-2 weapons are mergeable")
	var t3 = _fuse(p, t2a.weapon_id, t2b.weapon_id)
	t.eq(t3.tier, 3, "amalgam of two tier-2 is tier 3")
	t.eq(t3.get_child_count(), 4, "tier-3 holds all 4 leaf components")
	t.eq(p.weapons.size(), 1, "amalgam consumes both tier-2 into one weapon")
	t.ok(_all_leaves_reach_player(t3, p), "tier-3 components all reach the player (fire)")
	p.free()
