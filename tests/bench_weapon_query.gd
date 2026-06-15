extends Node
## Headless micro-benchmark for the AoE weapons that scan the live enemy field
## each tick (flame / laser / nova / lightning). Run it BEFORE and AFTER the
## all_enemies() -> enemies_in_radius() conversion to prove the change is a net win
## with no behavioral regression.
##
## Run:  godot --headless --path . res://tests/bench_weapon_query.tscn
## (runs as a scene, not --script, so project autoloads like Sfx are registered —
##  the weapon/Main scripts reference Sfx at compile time and won't load otherwise.)
##
## Method: a real Main (for its spatial grid), a real Player, and N real Enemy
## nodes in a fixed, seeded layout. For each weapon we time only its own
## `_physics_process` call against the rebuilt grid, ITERS times. Enemies are made
## immune to the weapon's damage type so take_hit early-returns *before* spawning
## damage numbers / crediting score (those costs are identical before and after and
## would only add noise + unbounded nodes). Enemy positions are restored each iter
## so knockback can't drift the field. The candidate-set iteration is the ONLY thing
## the conversion changes, so that is exactly what this isolates.

const N := 220              # ENEMY_CAP — worst case
const ITERS := 4000         # timed calls per weapon
const WARMUP := 200         # discarded calls to settle caches
const ARENA_HALF := 1100.0
const SEED := 1337


func _ready() -> void:
	var main := Main.new()
	add_child(main)                     # _ready sets Main.instance + grid methods

	var world := Node2D.new()
	main.add_child(world)

	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var enemies: Array = []
	var base_pos: Array = []
	for i in N:
		var e := Enemy.new()
		e.hp = 1e12                      # never dies, so the field stays at N
		e.max_hp = 1e12
		e.radius = 12.0
		e.main_ref = main
		var p := Vector2(rng.randf_range(-ARENA_HALF, ARENA_HALF),
			rng.randf_range(-ARENA_HALF, ARENA_HALF))
		e.position = p
		base_pos.append(p)
		world.add_child(e)               # _ready joins the "enemies" group
		enemies.append(e)

	var player := Player.new()
	player.is_local = false              # skip the camera
	player.peer_id = 1
	player.position = Vector2.ZERO       # center of the swarm
	world.add_child(player)

	# Base weapons + three representative fusion archetypes (orbit-blade halo, sweeping
	# beam, burn cone) — all per-frame scanners, instantiated as nested Fusions classes.
	var specs := [
		{"id": "flame", "node": WeaponFlame.new(), "dtype": Enemy.DMG_FIRE},
		{"id": "laser", "node": WeaponLaser.new(), "dtype": Enemy.DMG_ENERGY},
		{"id": "nova", "node": WeaponNova.new(), "dtype": Enemy.DMG_ENERGY},
		{"id": "lightning", "node": WeaponLightning.new(), "dtype": Enemy.DMG_ENERGY},
		{"id": "fus:teslahalo", "node": Fusions.TeslaHalo.new(), "dtype": Enemy.DMG_ENERGY},
		{"id": "fus:novabeam", "node": Fusions.NovaBeam.new(), "dtype": Enemy.DMG_ENERGY},
		{"id": "fus:plasmastorm", "node": Fusions.PlasmaStorm.new(), "dtype": Enemy.DMG_FIRE},
	]
	for s in specs:
		s.node.level = 3
		player.add_child(s.node)         # _ready resolves the owning player

	# Anything added to the world past this point (RingFx/LightningFx spawned by a weapon)
	# is transient; we free it back to this baseline each iter so nodes can't accumulate.
	var world_base := world.get_child_count()

	print("[bench] N=%d iters=%d warmup=%d seed=%d" % [N, ITERS, WARMUP, SEED])
	for s in specs:
		_bench_weapon(main, world, world_base, enemies, base_pos, s)

	get_tree().quit(0)


func _bench_weapon(main: Main, world: Node2D, world_base: int, enemies: Array,
		base_pos: Array, s: Dictionary) -> void:
	for e in enemies:
		e.immune_type = s.dtype          # take_hit pings off cheaply — no nodes/score/kills

	var w = s.node
	var total_us := 0
	var timed := 0
	for it in ITERS + WARMUP:
		for i in enemies.size():
			enemies[i].position = base_pos[i]   # cancel any knockback drift (untimed)
		main._rebuild_enemy_grid()              # shared per-tick index (untimed)
		_arm(w, s.id)                           # reset the weapon's fire gate
		var t0 := Time.get_ticks_usec()
		w._physics_process(0.05)
		var dt := Time.get_ticks_usec() - t0
		if it >= WARMUP:
			total_us += dt
			timed += 1
		while world.get_child_count() > world_base:   # free any FX the weapon spawned (untimed)
			world.get_child(world.get_child_count() - 1).free()

	var avg := float(total_us) / float(timed)
	print("[bench] %-13s avg %7.2f us/call   total %d us over %d calls"
		% [s.id, avg, total_us, timed])

	for e in enemies:
		e.immune_type = -1


## Reset each weapon's "may I fire this tick" gate so the scanning hot loop runs on
## every call (otherwise cooldowns would skip most iterations).
func _arm(w, id: String) -> void:
	match id:
		"flame":
			w.tick = -1.0
		"laser":
			w.hit_cd.clear()    # no per-tick cooldown gate; clearing keeps the inner test live
		"nova":
			w.cooldown = -1.0
		"lightning":
			w.cooldown = -1.0
		"fus:teslahalo":
			w.hit_cd.clear()              # blade scan runs every frame; clearing keeps it live
		"fus:novabeam":
			w.hit_cd.clear()
			w.nova_cd = 999.0             # bench the per-frame beam scan, skip the nova sub-pulse
		"fus:plasmastorm":
			w.tick = -1.0                 # fire the cone scan
			w.bolt_cd = 999.0             # skip the chain-bolt sub-attack
