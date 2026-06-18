class_name PlasmaRing
extends Node2D
## Plasma Pulse ring: drops at the spot it was emitted (does not follow the
## player), then grows outward — slow at first, a fast burst past the
## halfway point. Damage scales with how far out an enemy gets caught: at
## base_max_radius (the un-scaled cfg.max_radius) it's 2x; since the actual
## max_radius can be larger when Area is invested, the ring can carry foes
## hit out there past 2x.

var age := 0.0
var r := 0.0
var max_radius := 220.0       # Area-scaled actual cap this ring grows to
var base_max_radius := 220.0  # un-scaled cfg.max_radius — the damage curve's reference
var thickness := 14.0
var grow_time := 2.4
var grow_frac_half := 0.12
var dmg := 4.0
var rehit := 0.45
var source_pid := -1
var source_weapon: WeaponBase
var hit_cd := {}


func _ready() -> void:
	add_to_group("plasma_rings")
	z_index = -1


func _physics_process(delta: float) -> void:
	age += delta
	var t := age / grow_time
	if t >= 1.0:
		queue_free()
		return
	if t <= 0.5:
		var u := t / 0.5
		r = max_radius * grow_frac_half * u * u
	else:
		var u := (t - 0.5) / 0.5
		r = max_radius * lerpf(grow_frac_half, 1.0, u * (2.0 - u))
	queue_redraw()
	var expired := []
	for k in hit_cd:
		hit_cd[k] -= delta
		if hit_cd[k] <= 0.0:
			expired.append(k)
	for k in expired:
		hit_cd.erase(k)
	var mult := 1.0 + r / base_max_radius  # farther from center = harder hit, uncapped past 2x
	for e in EnemyGrid.near(global_position, r + thickness * 0.5 + 64.0):
		var id := e.get_instance_id()
		if hit_cd.has(id):
			continue
		var dist := global_position.distance_to(e.global_position)
		if absf(dist - r) <= thickness * 0.5 + e.radius:
			hit_cd[id] = rehit  # re-hits a foe that lingers in the ring, not just once
			var d := dmg * mult
			if is_instance_valid(source_weapon):
				source_weapon.damage_dealt += d
			e.take_hit(d, e.global_position, Enemy.DMG_ENERGY, source_pid)


func _draw() -> void:
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(0.4, 0.85, 1.0, 0.25), thickness * 2.2)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(0.75, 0.97, 1.0, 0.9), thickness)
