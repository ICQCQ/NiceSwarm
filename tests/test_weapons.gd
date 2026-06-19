extends RefCounted
## Unit tests for the 13 base weapons: config integrity, the damage formula's
## monotonicity, and that each weapon's _init() sets a valid id + display name.

const IDS := ["bolt", "orbit", "nova", "glaive", "lightning", "flame", "mines",
	"missiles", "laser", "frost", "gravity", "turret", "venom"]

func run(t) -> void:
	t.suite("weapons")

	for id in IDS:
		if not WeaponConfig.BASE.has(id):
			t.ok(false, "WeaponConfig.BASE missing " + id)
			continue
		t.ok(true, "WeaponConfig.BASE has " + id)
		var b: Dictionary = WeaponConfig.BASE[id]
		t.gt(b.get("dmg", 0.0), 0.0, id + " dmg > 0")
		t.ge(b.get("growth", -1.0), 0.0, id + " growth >= 0")
		t.gt(b.get("cd", 0.0), 0.0, id + " cd > 0")
		# damage = dmg * (1 + growth*(level-1)) must not shrink from L1 to L3
		var d1: float = b.dmg * (1.0 + b.growth * 0.0)
		var d3: float = b.dmg * (1.0 + b.growth * 2.0)
		t.ge(d3, d1, id + " L3 dmg >= L1 dmg")

	# each weapon node's _init() assigns an id that exists in config + a display name
	var nodes := [WeaponBolt.new(), WeaponOrbit.new(), WeaponNova.new(), WeaponGlaive.new(),
		WeaponLightning.new(), WeaponFlame.new(), WeaponMines.new(), WeaponMissiles.new(),
		WeaponLaser.new(), WeaponFrost.new(), WeaponGravity.new(), WeaponTurret.new(), WeaponVenom.new()]
	t.eq(nodes.size(), IDS.size(), "one node per base weapon id")
	var seen := {}
	for w in nodes:
		t.ok(WeaponConfig.BASE.has(w.weapon_id), "weapon node id '%s' is in config" % w.weapon_id)
		t.ne(w.display_name, "", "weapon '%s' has a display_name" % w.weapon_id)
		seen[w.weapon_id] = true
		w.free()
	t.eq(seen.size(), IDS.size(), "weapon node ids are all distinct")

	# Flame Cone: the cone widens past Lv3 and is capped at 90 degrees half-angle
	# (180 total coverage), reached exactly at the Lv7 cap.
	var flame := WeaponFlame.new()
	flame.cfg = WeaponConfig.BASE["flame"]
	flame.level = 3
	t.approx(flame._half_angle(), WeaponConfig.BASE.flame.half_angle, 0.0001, "no widening at/below Lv3")
	flame.level = 7
	t.approx(flame._half_angle(), PI / 2.0, 0.0001, "Lv7 half-angle is 90 degrees (180 total coverage)")
	flame.free()

	# TurretNode.GUN_RETAINING_MODES: read via .get(mode, false), not .has(mode) — every
	# key in the dict exists, so .has() would (and once did) return true even for the
	# AoE-only modes explicitly listed with `false`, making them also fire bullets.
	for mode in TurretNode.GUN_RETAINING_MODES:
		var expect: bool = TurretNode.GUN_RETAINING_MODES[mode]
		var got: bool = TurretNode.GUN_RETAINING_MODES.get(mode, false)
		t.eq(got, expect, "GUN_RETAINING_MODES['%s'] read via .get() matches its stored value" % mode)
	t.ok(not TurretNode.GUN_RETAINING_MODES.get("flame", false), "flame mode does not retain the bolt gun")
	t.ok(not TurretNode.GUN_RETAINING_MODES.get("nova", false), "nova mode does not retain the bolt gun")
	t.ok(not TurretNode.GUN_RETAINING_MODES.get("lightning", false), "lightning mode does not retain the bolt gun")
	t.ok(TurretNode.GUN_RETAINING_MODES.get("venom", false), "venom mode does retain the bolt gun")
