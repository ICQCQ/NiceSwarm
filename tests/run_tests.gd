extends SceneTree
## Zero-dependency headless unit-test runner for NiceSwarm.
## Run:  godot --headless --path . --script res://tests/run_tests.gd
## Exits 0 if all pass, 1 on any failure (CI-friendly). Each tests/test_*.gd is a
## RefCounted with `func run(t)`; `t` is the Tester below.
##
## Scope: this covers the UNIT-testable surface — the pure config/data layers
## (GameConfig / WeaponConfig / EnemyConfig), formulas, Fusions, EnemyGrid, and the
## spawner's pure math (via a mock `main`). Scene/network/UI/_draw/_process functions
## on Main/Net/Player are exercised by the headless integration hooks instead
## (NICESWARM_NET=solo|host|join, NICESWARM_TEST=zoo|all_weapons|merge|bomber, NICESWARM_FF).

const MODULES := [
	"res://tests/test_config.gd",
	"res://tests/test_xp.gd",
	"res://tests/test_weapons.gd",
	"res://tests/test_enemies.gd",
	"res://tests/test_fusions.gd",
	"res://tests/test_spawner.gd",
	"res://tests/test_gems.gd",
]


func _initialize() -> void:
	var t := Tester.new()
	for path in MODULES:
		var script: GDScript = load(path)
		if script == null:
			t.fail_load(path)
			continue
		var mod = script.new()
		mod.run(t)
	var code := t.report()
	quit(code)


class Tester:
	var passed := 0
	var failed := 0
	var _suite := ""
	var _suite_n := 0

	func suite(name: String) -> void:
		_suite = name
		_suite_n = 0

	func ok(cond: bool, msg: String) -> void:
		_suite_n += 1
		if cond:
			passed += 1
		else:
			failed += 1
			print("  FAIL [%s] %s" % [_suite, msg])

	func eq(a, b, msg: String) -> void:
		ok(a == b, "%s — got %s, expected %s" % [msg, str(a), str(b)])

	func ne(a, b, msg: String) -> void:
		ok(a != b, "%s — both were %s" % [msg, str(a)])

	func gt(a, b, msg: String) -> void:
		ok(a > b, "%s — %s not > %s" % [msg, str(a), str(b)])

	func ge(a, b, msg: String) -> void:
		ok(a >= b, "%s — %s not >= %s" % [msg, str(a), str(b)])

	func approx(a: float, b: float, eps: float, msg: String) -> void:
		ok(absf(a - b) <= eps, "%s — got %s, expected ~%s" % [msg, str(a), str(b)])

	func fail_load(path: String) -> void:
		failed += 1
		print("  FAIL [loader] could not load %s" % path)

	func report() -> int:
		print("[tests] %d passed, %d failed" % [passed, failed])
		return 0 if failed == 0 else 1
