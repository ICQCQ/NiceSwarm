class_name StormShuriken
extends Node2D
## Thunder shuriken: always in one of 2 states -- flying out in a straight line
## to a random point near the player, or flying back in a straight line to a
## snapshot of where the player stood when that leg started (not a live homing
## target). Reaching the current leg's point switches to the other leg,
## looping forever. Each new fly-out point is picked roughly opposite (180 deg
## +- `out_angle_spread_deg`) of the previous fly-out's direction instead of a
## fully random angle, so it sweeps side to side instead of jittering to an
## unrelated point every loop.
##
## Speed traces a comet's orbit: fastest right as it reaches the player (its
## "perihelion") and slowest right as it reaches the far patrol point (its
## "aphelion", `min_speed`, a near-stop rather than a literal one so it can't
## stall mid-leg). `max_speed` -- the perihelion speed -- keeps climbing the
## longer this shuriken survives (`max_speed_growth` per second), so a
## long-lived one swings back faster and faster each pass. Each leg lerps
## smoothly from the speed it inherited at the previous handoff to that leg's
## target speed, by fraction of `patrol_range` covered -- so there's no snap
## at the handoff, just a continuous accelerate-in/coast-out rhythm.
##
## Touching the player does nothing for the first `recall_grace` seconds;
## after that, contact (checked against `contact_radius`, which tracks the
## player's actual body size, not the blade's Area-scaled hit_radius) recalls
## it for good and adds `recall_cd_penalty` to the weapon's cooldown.
##
## Damage (direct hit and lightning arc both) also climbs with age, by
## `age_dmg_growth` per second -- the longer this shuriken survives without
## being recalled, the harder every hit lands.

static var BOLT := PackedVector2Array([
	Vector2(0, -11), Vector2(3, -2), Vector2(-1, -2), Vector2(4, 11), Vector2(0, 3), Vector2(-4, 3),
])

var player: Player
var weapon: FusStormDisc
var source_pid := -1
var owner_weapon_id := -1

var damage := 2.0
var arc_damage := 0.0
var arc_range := 150.0
var hit_radius := 14.0
var contact_radius := 22.0
var patrol_range := 260.0
var speed := 420.0
var fly_back_speed_mult := 2.5   # starting perihelion speed multiplier, before max_speed_growth kicks in
var max_speed_growth := 0.0      # px/s gained per second alive -- the comet's escalating perihelion
var min_speed := 20.0            # px/s: near-stop floor at the far end of fly-out (never literal 0)
var out_angle_spread_deg := 20.0 # +- jitter around the 180 deg opposite-of-last-leg angle
var age_dmg_growth := 0.0        # fractional damage gained per second alive
var recall_grace := 3.0
var recall_cd_penalty := 5.0

var target_point := Vector2.ZERO
var flying_home := false
var last_out_angle := 0.0   # direction (from the player) of the most recent fly-out leg
var max_speed := 0.0        # current perihelion ceiling; grows with age, sampled at each fly-back launch
var leg_start_speed := 0.0  # speed inherited from the previous leg's handoff
var leg_end_speed := 0.0    # this leg's target speed (max_speed for fly-back, MIN_SPEED for fly-out)
var cur_speed := 0.0
var age := 0.0
var spin := 0.0
var hit_ids := {}


func _ready() -> void:
	add_to_group("storm_shurikens")
	max_speed = speed * fly_back_speed_mult
	cur_speed = speed
	leg_start_speed = speed
	leg_end_speed = min_speed
	last_out_angle = randf() * TAU
	target_point = player.global_position + Vector2.from_angle(last_out_angle) * patrol_range


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		queue_free()
		return
	age += delta
	spin += 12.0 * delta
	max_speed += max_speed_growth * delta

	var to_target := target_point - global_position
	var dist := to_target.length()
	var t := clampf(1.0 - dist / patrol_range, 0.0, 1.0)
	cur_speed = lerpf(leg_start_speed, leg_end_speed, t)
	if dist > 1.0:
		global_position += to_target / dist * cur_speed * delta
	queue_redraw()

	if dist <= hit_radius:
		_advance_leg(not flying_home)

	if age >= recall_grace and global_position.distance_to(player.global_position) <= contact_radius:
		if is_instance_valid(weapon):
			weapon.cooldown += recall_cd_penalty * weapon.fuse_rate()
		queue_free()
		return

	for e in EnemyGrid.near(global_position, hit_radius):
		if hit_ids.has(e.get_instance_id()):
			continue
		if global_position.distance_to(e.global_position) <= hit_radius + e.radius:
			hit_ids[e.get_instance_id()] = true
			var dmg_now := damage * (1.0 + age_dmg_growth * age)
			if is_instance_valid(weapon):
				weapon.damage_dealt += dmg_now
			e.take_hit(dmg_now, global_position, Enemy.DMG_PHYS, source_pid)
			if arc_damage > 0.0:
				_arc_from(e)


func _advance_leg(go_home: bool) -> void:
	flying_home = go_home
	hit_ids.clear()
	leg_start_speed = cur_speed
	if go_home:
		target_point = player.global_position
		leg_end_speed = max_speed
		return
	leg_end_speed = min_speed
	last_out_angle += PI + deg_to_rad(randf_range(-out_angle_spread_deg, out_angle_spread_deg))
	target_point = player.global_position + Vector2.from_angle(last_out_angle) * patrol_range


func _arc_from(src: Node2D) -> void:
	var best: Node2D = null
	var bd := arc_range * arc_range
	for e in EnemyGrid.near(src.global_position, arc_range):
		if e == src or hit_ids.has(e.get_instance_id()):
			continue
		var d: float = src.global_position.distance_squared_to(e.global_position)
		if d < bd:
			bd = d
			best = e
	if best == null:
		return
	var arc_dmg_now := arc_damage * (1.0 + age_dmg_growth * age)
	if is_instance_valid(weapon):
		weapon.damage_dealt += arc_dmg_now
	best.take_hit(arc_dmg_now, src.global_position, Enemy.DMG_ENERGY, source_pid)
	var fx := LightningFx.new()
	fx.points = [src.global_position, best.global_position]
	get_parent().add_child(fx)


func _draw() -> void:
	var scale_f := hit_radius / 14.0
	for i in 4:
		var a := spin + TAU * float(i) / 4.0
		var pts := PackedVector2Array()
		for p in BOLT:
			pts.append((p * scale_f).rotated(a))
		draw_colored_polygon(pts, Color(1.0, 0.92, 0.35) if i % 2 == 0 else Color(0.55, 0.95, 1.0))
	draw_circle(Vector2.ZERO, 3.5 * scale_f, Color(1.0, 1.0, 0.9))
