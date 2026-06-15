class_name TelegraphZone
extends Node2D
## A bombardier's telegraphed strike: a red danger circle that fills over `warn`
## seconds, then detonates and damages any player still inside. Host-authoritative
## (damage on host); clients receive it as a puppet and just show the warning so
## the player can react. Removal of the host node drives the detonation flash on
## clients (see main._apply_state STATE_TELEGRAPHS).

const EFFECT_DAMAGE := 0
const EFFECT_DISRUPT := 1  # Disruptor: instant strike — no damage, slows + dash-locks
const EFFECT_FIELD := 2    # Defiler: a lingering ground hazard that disrupts while you stand in it
const EFFECT_INTERCEPT := 3  # Interceptor (T1-3): a lingering field that destroys player projectiles
const FIELD_LINGER := 3.0

var radius := 95.0
var warn := 1.3
var damage := 2
var effect := EFFECT_DAMAGE
var life := 1.0  # EFFECT_INTERCEPT only: how long the field lingers once active
var t := 0.0
var puppet := false
var net_id := 0
var net_target := Vector2.ZERO  # unused (static) — kept for the generic sync path
var main_ref: Node


func _ready() -> void:
	add_to_group("telegraphs")
	z_index = -1
	if effect == EFFECT_INTERCEPT:  # register on both host and puppet — see EnemyGrid
		EnemyGrid.register_zone(self)


## EFFECT_INTERCEPT only: true once the warm-up telegraph has elapsed and the
## field is actively destroying projectiles. Checked by EnemyGrid.in_interceptor_zone.
func is_intercept_active() -> bool:
	return effect == EFFECT_INTERCEPT and t >= warn


func _physics_process(delta: float) -> void:
	t += delta
	queue_redraw()
	if puppet:
		return  # host owns the effect; puppet is freed by the removal diff
	if effect == EFFECT_FIELD:
		if t >= warn + FIELD_LINGER:
			main_ref.telegraphs_by_id.erase(net_id)
			queue_free()
			return
		if t >= warn:  # active hazard — disrupt anyone standing in it
			for p in main_ref.players.values():
				if not p.downed \
						and global_position.distance_to(p.global_position) <= radius + Player.HURT_RADIUS:
					p.apply_disrupt(0.4)  # short refresh: ends shortly after you leave
		return
	if effect == EFFECT_INTERCEPT:
		if t >= warn + life:
			main_ref.telegraphs_by_id.erase(net_id)
			queue_free()
		return
	if t >= warn:
		_detonate()


func _detonate() -> void:
	var fx := RingFx.new()
	fx.position = global_position
	fx.radius = radius * 0.6
	fx.max_radius = radius
	fx.life = 0.25
	fx.color = _zone_color()
	get_parent().add_child(fx)
	Sfx.play("boom", global_position)
	for p in main_ref.players.values():
		if p.downed \
				or global_position.distance_to(p.global_position) > radius + Player.HURT_RADIUS:
			continue
		if effect == EFFECT_DISRUPT:
			p.apply_disrupt(2.5)
		else:
			p.take_damage(damage)
	main_ref.telegraphs_by_id.erase(net_id)
	queue_free()


func _zone_color() -> Color:
	if effect == EFFECT_DAMAGE:
		return Color(1.0, 0.3, 0.2)
	if effect == EFFECT_INTERCEPT:
		return Color(0.3, 0.85, 0.95)  # cyan, matching the Jammer's self-field
	return Color(0.7, 0.3, 1.0)  # disrupt + field are purple


func _draw() -> void:
	var col := _zone_color()
	if effect == EFFECT_FIELD and t >= warn:
		# active lingering hazard — a steady, swirling field
		var a := 0.30
		if t > warn + FIELD_LINGER - 0.6:  # fade out at the end
			a *= clampf((warn + FIELD_LINGER - t) / 0.6, 0.0, 1.0)
		draw_circle(Vector2.ZERO, radius, Color(col.r, col.g, col.b, a))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(col.r, col.g, col.b, 0.8), 2.5)
		return
	if effect == EFFECT_INTERCEPT and t >= warn:
		# active jamming field — same look as a Jammer's self-centered field
		var a := 0.30
		if t > warn + life - 0.6:  # fade out as it expires
			a *= clampf((warn + life - t) / 0.6, 0.0, 1.0)
		draw_circle(Vector2.ZERO, radius, Color(col.r, col.g, col.b, a))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(col.r, col.g, col.b, 0.8), 2.5)
		return
	# Instant strikes (DAMAGE/DISRUPT) vanish the moment they fire — don't keep rendering the
	# circle on the client puppet during the ~sync-latency window before the removal diff frees
	# it (the removal diff still plays the detonation flash). FIELD/INTERCEPT returned above.
	if t >= warn:
		return
	var p := clampf(t / warn, 0.0, 1.0)
	# danger fill grows as the strike nears
	draw_circle(Vector2.ZERO, radius, Color(col.r, col.g, col.b, 0.10 + 0.22 * p))
	# pulsing outline
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 56, Color(col.r, col.g, col.b, 0.85), 3.0)
	# closing inner ring counts down the dodge window
	draw_arc(Vector2.ZERO, radius * (1.0 - p), 0.0, TAU, 40, col.lightened(0.2), 2.0)
