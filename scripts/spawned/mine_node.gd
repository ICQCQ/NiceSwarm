class_name MineNode
extends Node2D
## Armed mine: explodes when an enemy comes close, damaging an area.

var damage := 6.0
var source_pid := -1  # scoreboard: which player owns this
var blast_radius := 100.0
var trigger_radius := 55.0  # Area
var arm := 0.4  # arming delay so it doesn't pop the instant it drops
var life := 12.0  # Duration: stays armed this long before going inert
var spawn_missiles := 0  # fused Cluster Mine launches this many homing rockets
var fire_dps := 0.0      # fused Napalm Mine leaves a burning pool on blast
var fire_radius := 0.0
var fire_dur := 2.0
var freeze_slow := 0.0   # >0: slow enemies in blast (Glacial Mine); duration scales with damage
var freeze_dur := 0.0
var shrapnel_count := 0  # fused Shrapnel Mine: glaive shards fly outward on blast
var shrapnel_dmg := 0.0
var shrapnel_radius := 12.0
var beam_spokes := 0     # fused Beam Mine: laser spokes pulse outward on blast
var beam_dmg := 0.0
var beam_len := 0.0
var beam_burn_dur := 0.0
var chain_count := 0     # fused Tesla Mine: lightning chains out from the blast
var chain_dmg := 0.0
var chain_range := 0.0
var nova_radius := 0.0   # fused Nova Mine: a second, larger energy pulse on blast
var nova_dmg := 0.0
var venom_dps := 0.0     # fused Toxic Mine: leaves a toxic pool on blast
var venom_radius := 0.0
var venom_dur := 0.0
var t := 0.0

var _trigger: Area2D


func _ready() -> void:
	add_to_group("mines")
	z_index = -1  # ground object, under enemies
	# Event-driven trigger: only reacts when an enemy's body actually enters the
	# radius, instead of every mine scanning every enemy each physics frame.
	_trigger = Area2D.new()
	_trigger.collision_layer = 0
	_trigger.collision_mask = 2
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = trigger_radius
	cs.shape = circle
	_trigger.add_child(cs)
	_trigger.body_entered.connect(_on_body_entered)
	add_child(_trigger)


func _physics_process(delta: float) -> void:
	t += delta
	var arming := arm > 0.0
	arm -= delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	queue_redraw()
	if arming and arm <= 0.0:
		# just armed: catch any enemy that was already sitting inside
		for b in _trigger.get_overlapping_bodies():
			if b is Enemy:
				_explode()
				return


func _on_body_entered(body: Node) -> void:
	if arm <= 0.0 and body is Enemy:
		_explode()


func _explode() -> void:
	var fx := RingFx.new()
	fx.position = global_position
	fx.radius = 20.0
	fx.max_radius = blast_radius
	fx.life = 0.3
	fx.color = Color(1.0, 0.55, 0.2)
	get_parent().add_child(fx)
	Sfx.play("boom", global_position, -4.0)
	for e in EnemyGrid.near(global_position, blast_radius):
		if global_position.distance_to(e.global_position) <= blast_radius + e.radius:
			e.take_hit(damage, global_position, Enemy.DMG_PHYS, source_pid)
			if freeze_slow > 0.0:
				e.apply_slow(freeze_slow, freeze_dur)
	for i in spawn_missiles:
		var m := MissileProj.new()
		m.damage = damage * 0.5
		m.splash = blast_radius * 0.5
		m.velocity = Vector2.from_angle(TAU * i / maxi(spawn_missiles, 1)) * 260.0
		m.position = global_position
		m.source_pid = source_pid
		get_parent().add_child(m)
	if fire_dps > 0.0:
		var pud := VenomPuddle.new()
		pud.radius = fire_radius
		pud.damage = fire_dps
		pud.max_life = fire_dur
		pud.life = fire_dur
		pud.fiery = true
		pud.burn_dps = fire_dps
		pud.burn_dur = 1.0
		pud.position = global_position
		pud.source_pid = source_pid
		get_parent().add_child(pud)
	for i in shrapnel_count:
		var g := GlaiveProj.new()
		g.source_pid = source_pid
		g.velocity = Vector2.from_angle(TAU * float(i) / shrapnel_count) * 420.0
		g.damage = shrapnel_dmg
		g.hit_radius = shrapnel_radius
		g.position = global_position
		get_parent().add_child(g)
	if beam_spokes > 0:
		var jitter := randf() * TAU
		for s in beam_spokes:
			var dir := Vector2.from_angle(jitter + TAU * float(s) / beam_spokes)
			for e in EnemyGrid.near(global_position, beam_len):
				var rel: Vector2 = e.global_position - global_position
				var along := clampf(rel.dot(dir), 0.0, beam_len)
				if (dir * along).distance_to(rel) <= 8.0 + e.radius:
					e.take_hit(beam_dmg, global_position + dir * along, Enemy.DMG_ENERGY, source_pid)
					if beam_burn_dur > 0.0:
						e.apply_burn(beam_dmg * 0.3, beam_burn_dur)
			var bfx := LightningFx.new()
			bfx.points = [global_position, global_position + dir * beam_len]
			get_parent().add_child(bfx)
	if chain_count > 0:
		var visited := {}
		for e in EnemyGrid.near(global_position, blast_radius):
			if global_position.distance_to(e.global_position) <= blast_radius + e.radius:
				visited[e.get_instance_id()] = true
		var from_pos := global_position
		for i in chain_count:
			var best: Node2D = null
			var bd := chain_range * chain_range
			for e in EnemyGrid.near(from_pos, chain_range):
				if visited.has(e.get_instance_id()):
					continue
				var d: float = from_pos.distance_squared_to(e.global_position)
				if d < bd:
					bd = d
					best = e
			if best == null:
				break
			visited[best.get_instance_id()] = true
			best.take_hit(chain_dmg, from_pos, Enemy.DMG_ENERGY, source_pid)
			var cfx := LightningFx.new()
			cfx.points = [from_pos, best.global_position]
			get_parent().add_child(cfx)
			from_pos = best.global_position
	if nova_radius > 0.0:
		for e in EnemyGrid.near(global_position, nova_radius):
			if global_position.distance_to(e.global_position) <= nova_radius + e.radius:
				e.take_hit(nova_dmg, global_position, Enemy.DMG_ENERGY, source_pid)
		var nfx := RingFx.new()
		nfx.position = global_position
		nfx.radius = blast_radius
		nfx.max_radius = nova_radius
		nfx.life = 0.35
		nfx.color = Color(1.0, 0.5, 0.9)
		get_parent().add_child(nfx)
	if venom_dps > 0.0:
		var tpud := VenomPuddle.new()
		tpud.radius = venom_radius
		tpud.damage = venom_dps
		tpud.max_life = venom_dur
		tpud.life = venom_dur
		tpud.burn_dps = venom_dps * 0.5
		tpud.burn_dur = venom_dur * 0.5
		tpud.position = global_position
		tpud.source_pid = source_pid
		get_parent().add_child(tpud)
	queue_free()


func _draw() -> void:
	var blink := fmod(t, 0.8) < 0.4
	draw_circle(Vector2.ZERO, 7.0, Color(0.35, 0.35, 0.4))
	draw_circle(Vector2.ZERO, 2.5, Color(1.0, 0.25, 0.2) if blink else Color(0.5, 0.15, 0.1))
