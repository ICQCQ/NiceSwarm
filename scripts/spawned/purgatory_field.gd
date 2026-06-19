class_name PurgatoryField
extends Node2D
## Purgatory: an eerie violet field that lingers where dropped, dealing slow
## chip damage and igniting everyone inside. Enemies caught in it are marked
## (Enemy.apply_vuln) -- they take extra damage from every source, incoming
## slows bite twice as hard, and their burn can't tick down while marked.

var radius := 60.0
var source_pid := -1  # scoreboard: which player owns this
var source_weapon: WeaponBase
var damage := 1.0      # per tick, low chip damage
var max_life := 4.0
var life := 4.0
var burn_dps := 0.0
var burn_dur := 0.0
var vuln_stat_mult := 1.0  # Power scalar — deepens the mark's base bonus (see AfflictConfig.deepened)
var vuln_dur := 1.0
var tick := 0.0
var redraw_tick := 0.0
var t := 0.0


func _ready() -> void:
	z_index = -1
	queue_redraw()


func _physics_process(delta: float) -> void:
	life -= delta
	t += delta
	if life <= 0.0:
		queue_free()
		return
	redraw_tick -= delta
	if redraw_tick <= 0.0:
		redraw_tick = 0.08  # eerie wisps need a faster redraw than a plain puddle's slow fade
		queue_redraw()
	tick -= delta
	if tick > 0.0:
		return
	tick = 0.4
	for e in EnemyGrid.near(global_position, radius):
		if global_position.distance_to(e.global_position) <= radius + e.radius:
			if is_instance_valid(source_weapon):
				source_weapon.damage_dealt += damage
			e.take_hit(damage, null, Enemy.DMG_PHYS, source_pid)
			if burn_dps > 0.0:
				e.apply_burn(burn_dps, burn_dur, 1.0, source_pid)
			e.apply_vuln(vuln_stat_mult, vuln_dur)


func _draw() -> void:
	var a := clampf(life / max_life, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(t * 2.2)
	draw_circle(Vector2.ZERO, radius, Color(0.3, 0.08, 0.38, 0.16 * a))
	draw_arc(Vector2.ZERO, radius * 0.94, 0.0, TAU, 32, Color(0.55, 0.2, 0.7, (0.3 + 0.25 * pulse) * a), 2.0)
	# drifting violet wisps -- gives the field a haunted, restless feel
	for i in 5:
		var ang := t * 0.6 + TAU * i / 5.0
		var r := radius * (0.25 + 0.6 * fmod(t * 0.22 + i * 0.37, 1.0))
		var p := Vector2.from_angle(ang) * r
		draw_circle(p, 3.0 + 2.0 * pulse, Color(0.7, 0.35, 0.85, 0.45 * a))
	# stray spirit motes drifting around the rim
	for i in 3:
		var sa := t * 1.7 + TAU * i / 3.0 + 1.0
		var sp := Vector2.from_angle(sa) * radius * 0.75
		draw_circle(sp, 1.6, Color(0.85, 0.7, 1.0, 0.7 * a))
