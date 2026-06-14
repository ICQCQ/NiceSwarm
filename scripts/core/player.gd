class_name Player
extends CharacterBody2D
## A player. is_local: reads input, owns the camera. Remote players are puppets
## interpolating toward synced positions. HP/damage is authoritative on the host
## for everyone; clients receive it via Net.

signal died
signal health_changed(hp: int, max_hp: int)

const RADIUS := 14.0
const DASH_TIME := 0.18
const DASH_SPEED_MULT := 3.4
const COLORS: Array[Color] = [
	Color(0.45, 0.9, 1.0), Color(0.5, 1.0, 0.6),
	Color(1.0, 0.85, 0.4), Color(1.0, 0.55, 0.8),
]

var peer_id := 1
var color_idx := 0
var is_local := true
var arena := Rect2(-1200, -1200, 2400, 2400)

# Stats (modified by upgrades)
var max_hp := 5
var hp := 5
var move_speed := 220.0
var damage_mult := 1.0   # Power
var rate_mult := 1.0     # Haste — lower = faster firing
var area_mult := 1.0     # Area — AoE radii, reach, projectile size
var duration_mult := 1.0 # Duration — lifetimes of summons/trails/projectiles
var pickup_range := 90.0
var dash_cooldown := 2.5

var facing := Vector2.RIGHT
var invuln := 0.0
var shake := 0.0
var dash_timer := 0.0   # cooldown remaining
var dash_active := 0.0  # dash duration remaining
var dash_dir := Vector2.ZERO
var disrupt_timer := 0.0  # Disruptor debuff: slows movement (dash still works)
var downed := false
var revive_progress := 0.0
var debug_god := false  # debug panel: ignore all damage
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
	invuln = maxf(invuln - delta, 0.0)
	queue_redraw()
	if downed:
		velocity = Vector2.ZERO
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
	if debug_god:
		return
	if invuln > 0.0 or dash_active > 0.0 or remote_dashing:
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
	var sig := Fusions.make(id_a, id_b)
	if sig != null:
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


func _draw() -> void:
	var body := COLORS[color_idx % COLORS.size()]
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
		draw_circle(Vector2.ZERO, RADIUS, col)
		draw_circle(Vector2.ZERO, RADIUS * 0.45, Color(0.1, 0.25, 0.4))
		if disrupt_timer > 0.0:  # disrupted: a jittery purple ring
			draw_arc(Vector2.ZERO, RADIUS + 5.0, 0.0, TAU, 16,
				Color(0.7, 0.3, 1.0, 0.9), 2.5)
	if not is_local:
		draw_string(ThemeDB.fallback_font, Vector2(-12.0, -RADIUS - 10.0),
			"P%d" % (color_idx + 1), HORIZONTAL_ALIGNMENT_CENTER, 24.0, 13, body)
