class_name Player
extends CharacterBody2D
## A player. is_local: reads input, owns the camera. Remote players are puppets
## interpolating toward synced positions. HP/damage is authoritative on the host
## for everyone; clients receive it via Net.

signal died
signal health_changed(hp: int, max_hp: int)

const RADIUS := 14.0
const HURT_RADIUS := RADIUS * 0.8  # forgiving hurtbox — smaller than the drawn body
const DASH_TIME := 0.18
const DASH_SPEED_MULT := 3.4
# Players sit in the cool/bright band (blue/green/yellow) so they read as the
# approachable anchor; the warm band (red/orange/deep-violet) is reserved for
# enemies. No slot may be pink/orange/purple — those collide with enemy hues.
const COLORS: Array[Color] = [
	Color(0.45, 0.9, 1.0), Color(0.55, 1.0, 0.55),
	Color(1.0, 0.85, 0.35), Color(0.25, 0.95, 0.8),
	Color(0.45, 0.62, 1.0), Color(0.8, 1.0, 0.45),
	Color(0.6, 0.95, 0.9), Color(0.9, 1.0, 0.55),
]
# Player avatar silhouettes (lobby-selectable). Names match the glyphs the lobby
# UI shows in the roster/appearance preview.
const SHAPES: Array[String] = ["circle", "square", "triangle", "diamond", "star"]
const SHAPE_GLYPHS := {
	"circle": "●", "square": "■", "triangle": "▲", "diamond": "◆", "star": "★",
}


## Unicode marker for a player's character shape — prepended to their name in the HUD/scoreboard.
static func shape_glyph(shape_idx_: int) -> String:
	return SHAPE_GLYPHS[SHAPES[shape_idx_ % SHAPES.size()]]

var peer_id := 1
var color_idx := 0
var shape_idx := 0
var player_name := "Player"
var is_local := true
var arena := Rect2(-1200, -1200, 2400, 2400)

# Stats (modified by upgrades)
var max_hp := 5
var hp := 5
var move_speed := 220.0
var power_stat := 1.0     # Power from upgrade picks (st_power); the base for damage_mult
var damage_mult := 1.0   # Power — derived each frame: power_stat * party-level scaling (see _physics_process)
var rate_mult := 1.0     # Haste — lower = faster firing
var area_mult := 1.0     # Area — AoE radii, reach, projectile size
var duration_mult := 1.0 # Duration — lifetimes of summons/trails/projectiles
var pickup_range := 90.0
var dash_cooldown := 2.5
var stat_levels := {}    # stat-upgrade id ("st_power"…) -> times picked, for the HUD icons

var facing := Vector2.RIGHT
var invuln := 0.0
var shake := 0.0
var lethal_taken := 0.0  # FF lethality instrument: would-be damage eaten while debug_god (see take_damage)
var dash_timer := 0.0   # cooldown remaining
var dash_active := 0.0  # dash duration remaining
var dash_dir := Vector2.ZERO
var disrupt_timer := 0.0  # Disruptor debuff: slows movement (dash still works)
var downed := false
var revive_progress := 0.0
## mid-game: owner's connection dropped; held in place until they rejoin. Toggles
## physics processing on every weapon (and its fused components) so a ghost stops
## firing/dealing damage entirely without each weapon having to check this flag.
var disconnected := false:
	set(value):
		disconnected = value
		for w in weapons:
			w.set_physics_process(not value)
			if w is WeaponFused:
				for c in w.components:
					c.set_physics_process(not value)
var debug_god := false  # debug panel: ignore all damage
var safe := false  # host-authoritative: ignore damage while this player's in-game menu is open
var menu_frozen := false  # local: hold still while our own in-game menu is open
var bot := false  # headless sim: host-driven kiting AI (overrides input/puppet movement)
var weapons: Array = []
var cam: Camera2D

# Remote-puppet state (set from network)
var net_target := Vector2.ZERO
var remote_dashing := false


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	cs.shape = circle
	add_child(cs)
	z_index = 100  # always on top of the whole world (swarm, projectiles, FX) so the glyph/effect/name stay visible
	net_target = global_position

	if is_local:
		cam = Camera2D.new()
		cam.limit_left = int(arena.position.x)
		cam.limit_top = int(arena.position.y)
		cam.limit_right = int(arena.end.x)
		cam.limit_bottom = int(arena.end.y)
		add_child(cam)
		cam.make_current()

	health_changed.emit(hp, max_hp)


func _physics_process(delta: float) -> void:
	# Weapon base power scales with party level on top of Power picks + per-weapon
	# levels. Recomputed before any early-return so bots/puppets stay current; runs
	# before child weapons' _physics_process (parent-first tree order) so they read
	# the fresh value the same frame.
	if Main.instance != null:
		damage_mult = power_stat * (1.0 + GameConfig.WEAPON_LEVEL_POWER * (Main.instance.level - 1))
	invuln = maxf(invuln - delta, 0.0)
	queue_redraw()
	if downed:
		velocity = Vector2.ZERO
		_update_cam(delta)
		return
	if is_local and menu_frozen:  # our in-game menu is open: hold still (host marks us safe)
		velocity = Vector2.ZERO
		_update_cam(delta)
		return
	if bot:  # headless sim autopilot
		_bot_step(delta)
		_update_cam(delta)
		return

	if is_local:
		_local_move(delta)
	else:
		var to := net_target - global_position
		global_position = global_position.lerp(net_target, minf(14.0 * delta, 1.0))
		velocity = to * 10.0  # rough speed estimate, used by venom's "moving" check
		if remote_dashing and dash_active <= 0.0:
			Sfx.play("dash", global_position)
		dash_active = 0.1 if remote_dashing else 0.0
	_update_cam(delta)


func _local_move(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if dir != Vector2.ZERO:
		facing = dir.normalized()

	dash_timer = maxf(dash_timer - delta, 0.0)
	disrupt_timer = maxf(disrupt_timer - delta, 0.0)
	var disrupted := disrupt_timer > 0.0
	var spd := move_speed * (0.5 if disrupted else 1.0)  # Disruptor slows you
	var dash_pressed := Input.is_physical_key_pressed(KEY_SPACE) \
		or Input.is_physical_key_pressed(KEY_SHIFT)
	if dash_active > 0.0:
		dash_active -= delta
		velocity = dash_dir * move_speed * DASH_SPEED_MULT
	elif dash_pressed and dash_timer <= 0.0 and dir != Vector2.ZERO:
		dash_active = DASH_TIME
		dash_timer = dash_cooldown
		dash_dir = dir.normalized()
		invuln = maxf(invuln, 0.3)
		velocity = dash_dir * move_speed * DASH_SPEED_MULT
		Sfx.play("dash", global_position)
	else:
		velocity = dir.normalized() * spd if dir != Vector2.ZERO else Vector2.ZERO
	move_and_slide()
	global_position = global_position.clamp(
		arena.position + Vector2(RADIUS, RADIUS),
		arena.end - Vector2(RADIUS, RADIUS)
	)


## Headless-sim autopilot: kite the swarm. Flee the local enemy cluster (nearer enemies push
## harder), drift back toward the arena center when near an edge, aim at the nearest enemy so
## directional weapons connect, and dash out when something gets too close.
func _bot_step(delta: float) -> void:
	dash_timer = maxf(dash_timer - delta, 0.0)
	var nearest: Node2D = null
	var nd := INF
	var crowd := 0   # threats pressing in close — triggers a proactive escape dash
	if Main.instance != null:
		for e in Main.instance.enemies_in_radius(global_position, 220.0):
			var d := global_position.distance_to(e.global_position)
			if d < nd:
				nd = d
				nearest = e
			if d < 130.0:
				crowd += 1
	# Comet-tail kite: orbit the arena center at ~58% radius, always moving tangentially so the
	# swarm trails behind and we run into fresh space; a radial nudge holds the orbit ring.
	var center := arena.get_center()
	var rel := global_position - center
	var rl := rel.length()
	var half := arena.size.x * 0.5
	var tangent := Vector2.from_angle((rel.angle() if rl > 1.0 else 0.0) + PI * 0.5)
	var radial := rel.normalized() * ((half * 0.58 - rl) * 0.012) if rl > 1.0 else Vector2.ZERO
	var dir := (tangent + radial).normalized()
	# Vacuum XP: drift toward the nearest dropped gem so the kite actually banks the XP it earns —
	# a pure orbit leaves its kill-tail of gems uncollected -> no levels -> weak build -> death.
	var gem_off := Vector2.ZERO
	var gnd := 250000.0  # only divert for gems within ~500px
	for g in get_tree().get_nodes_in_group("gems"):
		var gd: float = global_position.distance_squared_to(g.global_position)
		if gd < gnd:
			gnd = gd
			gem_off = g.global_position - global_position
	if gem_off != Vector2.ZERO:
		dir = (dir + gem_off.normalized() * 0.8).normalized()
	# Seek the nearest heart when hurt — with no passive healing, accumulated touches end the run.
	if hp < max_hp and Main.instance != null:
		var heart_off := Vector2.ZERO
		var hnd := 360000.0  # nearest heart within ~600px
		for pk in Main.instance.pickups_by_id.values():
			if is_instance_valid(pk) and pk.kind == "heart":
				var pd: float = global_position.distance_squared_to(pk.global_position)
				if pd < hnd:
					hnd = pd
					heart_off = pk.global_position - global_position
		if heart_off != Vector2.ZERO:
			dir = (dir + heart_off.normalized() * (1.2 if hp <= 2 else 0.6)).normalized()
	if nearest != null:
		facing = (nearest.global_position - global_position).normalized()
		if nd < 120.0:  # a close threat bends the path away from it (overrides gem greed)
			dir = (dir + (global_position - nearest.global_position).normalized() * 1.1).normalized()
	# Dodge telegraphed strikes: step out of any active danger zone we're standing in (casters
	# unlock ~150s and their undodged strikes were a major killer for the kite).
	for tz in get_tree().get_nodes_in_group("telegraphs"):
		var toff: Vector2 = global_position - tz.global_position
		var td := toff.length()
		if td < tz.radius + 55.0:
			var away := toff.normalized() if td > 1.0 else Vector2.from_angle(facing.angle() + PI)
			dir = (dir + away * 2.0).normalized()
	# Revive a downed ally (co-op's key safety net): path to reviver range (~70px) and hold
	# position there to channel the revive — but only when not swarmed (crowd < 3), never suicidal.
	if Main.instance != null and crowd < 3:
		var ally_off := Vector2.ZERO
		var nad := INF
		for q in Main.instance.players.values():
			if q != self and q.downed:
				var ad: float = global_position.distance_squared_to(q.global_position)
				if ad < nad:
					nad = ad
					ally_off = q.global_position - global_position
		if ally_off != Vector2.ZERO:
			if ally_off.length() < 62.0:
				dir = Vector2.ZERO  # hold to channel the revive
			else:
				dir = (dir + ally_off.normalized() * 1.5).normalized()
	if dash_active > 0.0:
		dash_active -= delta
		velocity = dash_dir * move_speed * DASH_SPEED_MULT
	elif dash_timer <= 0.0 and (nd < 80.0 or crowd >= 3):  # break contact before getting pinned
		dash_active = DASH_TIME
		dash_timer = dash_cooldown
		dash_dir = dir
		invuln = maxf(invuln, 0.3)
		velocity = dash_dir * move_speed * DASH_SPEED_MULT
	else:
		velocity = dir * move_speed if dir != Vector2.ZERO else Vector2.ZERO
	move_and_slide()
	global_position = global_position.clamp(
		arena.position + Vector2(RADIUS, RADIUS), arena.end - Vector2(RADIUS, RADIUS))


func _update_cam(delta: float) -> void:
	if cam == null:
		return
	if shake > 0.0:
		shake = maxf(shake - 40.0 * delta, 0.0)
		cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake
	else:
		cam.offset = Vector2.ZERO


func add_weapon(id: String) -> void:
	var w: Node2D
	match id:
		"bolt":
			w = WeaponBolt.new()
		"orbit":
			w = WeaponOrbit.new()
		"nova":
			w = WeaponNova.new()
		"glaive":
			w = WeaponGlaive.new()
		"lightning":
			w = WeaponLightning.new()
		"flame":
			w = WeaponFlame.new()
		"mines":
			w = WeaponMines.new()
		"missiles":
			w = WeaponMissiles.new()
		"laser":
			w = WeaponLaser.new()
		"frost":
			w = WeaponFrost.new()
		"gravity":
			w = WeaponGravity.new()
		"turret":
			w = WeaponTurret.new()
		"venom":
			w = WeaponVenom.new()
	weapons.append(w)
	add_child(w)


func get_weapon(id: String) -> Node2D:
	for w in weapons:
		if w.weapon_id == id:
			return w
	return null


func nearest_enemy(max_range: float) -> Node2D:
	# Delegates to the shared per-tick spatial grid (Main) instead of scanning the whole
	# "enemies" group every call — this covers most weapon/fusion targeting at one site.
	if Main.instance == null:
		return null
	return Main.instance.nearest_enemy_to(global_position, max_range)


func take_damage(amount: int) -> void:
	if hp <= 0 or downed:
		return
	if invuln > 0.0 or dash_active > 0.0 or remote_dashing:
		return  # i-frames / dash block the hit (real or god) — no behavioral change vs before
	if debug_god or safe or disconnected:
		if debug_god:
			lethal_taken += amount  # FF lethality instrument: damage a mortal would have eaten here
		return
	hp -= amount
	invuln = 0.9
	shake = 10.0
	Sfx.play("hurt", global_position)
	if hp <= 0:
		hp = 0
		downed = true
		revive_progress = 0.0
	health_changed.emit(hp, max_hp)
	if downed:
		died.emit()


func revive() -> void:
	downed = false
	revive_progress = 0.0
	hp = maxi(1, int(ceil(max_hp / 2.0)))
	invuln = 2.0
	Sfx.play("revive", global_position)
	health_changed.emit(hp, max_hp)


## Fuses two owned maxed weapons. A signature recipe (two base weapons) yields a
## DISTINCT new weapon; anything else (deep merges, uncovered pairs) falls back to
## a generic WeaponFused that runs both components together.
func merge_weapons(id_a: String, id_b: String) -> void:
	var a := get_weapon(id_a)
	var b := get_weapon(id_b)
	if a == null or b == null or a == b:
		return
	if not Fusions.can_merge(a.tier, b.tier):
		return  # a final-tier fusion can't be merged further (no T3+)
	var new_tier := Fusions.merged_tier(a.tier, b.tier)
	var sig := Fusions.make(id_a, id_b)
	if sig != null:
		sig.tier = new_tier
		weapons.erase(a)
		weapons.erase(b)
		a.queue_free()
		b.queue_free()
		add_child(sig)
		weapons.append(sig)
		return
	var parts: Array = []
	var shells: Array = []
	for w in [a, b]:
		weapons.erase(w)
		if w is WeaponFused:
			parts.append_array(w.components)
			shells.append(w)
		else:
			parts.append(w)
	var f := WeaponFused.new()
	f.tier = new_tier
	add_child(f)
	f.setup(parts)  # re-parents components out of any old shells
	weapons.append(f)
	for s in shells:
		s.components = []
		s.queue_free()


func apply_disrupt(duration: float) -> void:
	if invuln > 0.0 or dash_active > 0.0:
		return  # dashing through a disruptor zone shrugs it off
	if disrupt_timer <= 0.0:  # only play the hit sound on the initial debuff, not every refresh tick
		Sfx.play("hurt", global_position)
	disrupt_timer = maxf(disrupt_timer, duration)


func heal(amount: int) -> void:
	hp = mini(hp + amount, max_hp)
	health_changed.emit(hp, max_hp)


func gain_vitality() -> void:
	max_hp += 1
	hp = mini(hp + 2, max_hp)
	health_changed.emit(hp, max_hp)


## Draws a player avatar silhouette (circle/square/triangle/diamond/star),
## shared by the in-world Player and the lobby's appearance preview/roster.
static func draw_shape(node: CanvasItem, shape_idx_: int, radius: float, col: Color,
		center: Vector2 = Vector2.ZERO) -> void:
	var shape: String = SHAPES[shape_idx_ % SHAPES.size()]
	match shape:
		"square", "diamond", "triangle":
			var n := 3 if shape == "triangle" else 4
			var a0 := -PI / 2.0 + (PI / 4.0 if shape == "square" else 0.0)
			var pts := PackedVector2Array()
			for i in n:
				pts.append(center + Vector2.from_angle(a0 + TAU * i / n) * radius)
			node.draw_colored_polygon(pts, col)
		"star":
			var pts := PackedVector2Array()
			for i in 10:
				var r := radius if i % 2 == 0 else radius * 0.45
				pts.append(center + Vector2.from_angle(-PI / 2.0 + TAU * i / 10.0) * r)
			node.draw_colored_polygon(pts, col)
		_:
			node.draw_circle(center, radius, col)


func _draw() -> void:
	var body := COLORS[color_idx % COLORS.size()]
	if disconnected:
		body.a = 0.35
	if downed:
		draw_circle(Vector2.ZERO, RADIUS, Color(0.25, 0.28, 0.33))
		draw_line(Vector2(-7, -7), Vector2(7, 7), Color(0.9, 0.3, 0.3), 3.0)
		draw_line(Vector2(-7, 7), Vector2(7, -7), Color(0.9, 0.3, 0.3), 3.0)
		if revive_progress > 0.0:
			draw_arc(Vector2.ZERO, RADIUS + 7.0, -PI / 2.0,
				-PI / 2.0 + TAU * revive_progress, 24, Color(0.5, 1.0, 0.6), 4.0)
	else:
		var col := body
		if dash_active > 0.0:
			col = col.lightened(0.5)
		elif invuln > 0.0 and fmod(invuln, 0.2) > 0.1:
			col.a = 0.35
		# pulsing "grow" ring — expands outward and fades in the player's colour, so the
		# player pops out of a dense swarm at a glance (drawn under the body so it stays crisp)
		var pt := fmod(Time.get_ticks_msec() * 0.0012, 1.0)
		draw_arc(Vector2.ZERO, RADIUS + 4.0 + pt * 18.0, 0.0, TAU, 32,
			Color(body.r, body.g, body.b, (1.0 - pt) * 0.5 * body.a), 2.5)
		# dark backing halo: separates the bright body from the swarm on any color
		draw_circle(Vector2.ZERO, RADIUS + 3.0, Color(0.0, 0.0, 0.0, 0.5 * col.a))
		Player.draw_shape(self, shape_idx, RADIUS, col)
		draw_circle(Vector2.ZERO, RADIUS * 0.45, Color(0.1, 0.25, 0.4, col.a))
		# facing notch: a slim bright wedge showing aim/front (player identity)
		var fa := facing.angle()
		var notch := PackedVector2Array([
			Vector2.from_angle(fa) * (RADIUS + 5.0),
			Vector2.from_angle(fa + 0.45) * (RADIUS - 1.0),
			Vector2.from_angle(fa - 0.45) * (RADIUS - 1.0)])
		draw_colored_polygon(notch, Color(1.0, 1.0, 1.0, 0.9 * col.a))
		if disrupt_timer > 0.0:  # disrupted: a jittery purple ring
			draw_arc(Vector2.ZERO, RADIUS + 5.0, 0.0, TAU, 16,
				Color(0.7, 0.3, 1.0, 0.9), 2.5)
	if not is_local:
		var ping := 0
		if Main.instance != null:
			ping = int(Main.instance.net_pings.get(peer_id, 0))
		var ping_s := ("  %dms" % ping) if ping > 0 else ""
		# glyph (character) + name, drawn in the player's own colour (the colour cue), + ping
		var label := "%s %s%s%s" % [Player.shape_glyph(shape_idx), player_name, ping_s,
			(" (away)" if disconnected else "")]
		draw_string(ThemeDB.fallback_font, Vector2(-75.0, -RADIUS - 10.0),
			label, HORIZONTAL_ALIGNMENT_CENTER, 150.0, 13, body)
