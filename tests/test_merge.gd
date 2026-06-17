extends RefCounted
## Reproduction/regression for the merge system under the same-kind rule (base+base ->
## signature fusion; signature+signature -> amalgam; amalgam is terminal). Asserts node
## structure survives, that two amalgams can't merge, and that two of the SAME signature
## fusion DO amalgamate (the "2 Implosion Salvo do nothing, wastes a pick" bug).
## merge_weapons only restructures nodes (no Main), so a bare off-tree Player works.

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
	# #1: a fresh signature fusion carries the born damage boost (not a downgrade from inputs)
	t.eq(a1.born_dmg, GameConfig.FUSION_BORN_DMG, "fresh signature fusion has the born damage boost")
	# ...and is born firing near-max COUNTS so the action doesn't cliff to the Lv1 minimum
	# (the maxed-Nova "many wide pulses -> one pulse" downgrade). It's still integer level 1.
	t.eq(a1.born_count_floor, GameConfig.FUSION_BORN_COUNT_FLOOR, "fresh signature fusion has the born count floor")
	t.eq(a1.level, 1, "fresh signature fusion is still integer level 1 (gates the next merge)")
	t.eq(a1.count_level(), GameConfig.FUSION_BORN_COUNT_FLOOR, "fresh fusion count_level() is floored near max at birth")
	# base weapons are untouched: no floor, so a Lv1 base weapon fires its Lv1 count
	# (use "laser" — still present here; bolt/nova/frost/lightning were consumed by a1/b1)
	t.eq(p.get_weapon("laser").born_count_floor, 0, "base weapon has no born count floor")
	t.eq(p.get_weapon("laser").count_level(), 1, "Lv1 base weapon count_level() is 1 (byte-identical to before)")
	var t2a = _fuse(p, a1.weapon_id, b1.weapon_id)
	t.eq(t2a.tier, 2, "tier-2 #1 has tier 2")
	t.eq(t2a.get_child_count(), 2, "tier-2 #1 holds its 2 components")

	# --- tier-2 #2 = (glaive+venom) merged with (laser+orbit) ---
	var c1 = _fuse(p, "glaive", "venom")
	var d1 = _fuse(p, "laser", "orbit")
	var t2b = _fuse(p, c1.weapon_id, d1.weapon_id)
	t.eq(t2b.tier, 2, "tier-2 #2 has tier 2")
	t.eq(t2b.get_child_count(), 2, "tier-2 #2 holds its 2 components")
	# #2: leveling an amalgam buffs ALL its components' stats by AMALGAM_STAT_PER_LEVEL/level
	t.approx(t2b.components[0].fuse_pow, 1.0, 0.0001, "fresh amalgam has no stat boost yet")
	t2b.level_up()
	t.approx(t2b.components[0].fuse_pow, 1.0 + GameConfig.AMALGAM_STAT_PER_LEVEL,
		0.0001, "amalgam level-up scales component fuse_pow by the per-level boost")

	# both tier-2 weapons must coexist as distinct, owned, processing weapons
	t.eq(p.weapons.size(), 2, "exactly the two tier-2 weapons remain")
	t.ne(t2a.weapon_id, t2b.weapon_id, "the two tier-2 weapons have distinct ids")
	t.ok(p.get_weapon(t2a.weapon_id) != null, "tier-2 #1 is owned")
	t.ok(p.get_weapon(t2b.weapon_id) != null, "tier-2 #2 is owned")
	# every leaf of BOTH tier-2 weapons must resolve the Player, or it never fires
	t.ok(_all_leaves_reach_player(t2a, p), "tier-2 #1 components all reach the player (fire)")
	t.ok(_all_leaves_reach_player(t2b, p), "tier-2 #2 components all reach the player (fire)")

	# --- same-kind rule: two tier-2 amalgams CANNOT merge (amalgam is terminal) ---
	t.ok(not Fusions.can_merge(t2a.tier, t2b.tier), "two tier-2 amalgams can't merge (terminal)")
	var n_before := p.weapons.size()
	p.merge_weapons(t2a.weapon_id, t2b.weapon_id)
	t.eq(p.weapons.size(), n_before, "merging two amalgams is a no-op — both remain")

	# --- regression: merging TWO of the SAME signature fusion must work ---
	# (get_weapon returned the first instance for both sides -> a == b -> silent no-op,
	#  the "2 Implosion Salvo do nothing, wastes a pick" bug.)
	for wid in ["bolt", "nova"]:
		p.add_weapon(wid)
	var s1 = _fuse(p, "bolt", "nova")              # Plasma Burst #1 (tier 1)
	for wid in ["bolt", "nova"]:
		p.add_weapon(wid)
	var s2 = _fuse(p, "bolt", "nova")              # Plasma Burst #2 (tier 1)
	t.ne(s1, s2, "two distinct same-id fusion instances")
	t.eq(s1.weapon_id, s2.weapon_id, "...sharing one weapon_id")
	# both duplicates are parented under the player, so at runtime each resolves `player`
	# and fires (off-tree here so _ready hasn't run — assert the structure, like the leaf check)
	t.eq(s1.get_parent(), p, "duplicate #1 parented under player (resolves player -> fires)")
	t.eq(s2.get_parent(), p, "duplicate #2 parented under player (resolves player -> fires)")
	# leveling targets the LOWEST copy so duplicates level evenly (not just the first)
	s1.level = 3
	s2.level = 5
	t.eq(p.lowest_weapon("fus_plasma"), s1, "lowest_weapon picks the lower-level duplicate")
	var same_before := p.weapons.size()
	s1.level = GameConfig.MAX_WEAPON_LEVEL
	s2.level = GameConfig.MAX_WEAPON_LEVEL
	p.merge_weapons(s1.weapon_id, s2.weapon_id)    # same id on both sides
	t.eq(p.weapons.size(), same_before - 1, "two same-id fusions amalgamate into one (was a no-op bug)")
	var amal = p.weapons[p.weapons.size() - 1]
	t.ok(amal is WeaponFused, "the same-fusion merge produced an amalgam")
	t.eq(amal.tier, 2, "the same-fusion amalgam is tier 2")
	t.eq(amal.get_child_count(), 2, "amalgam holds both components")
	p.free()
