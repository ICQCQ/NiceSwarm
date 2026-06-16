class_name DebugPanel
extends Node
## Debug-build-only testing panel: F1 toggles it. God mode + one-click weapon
## grant/level-up for the local player, routed through the normal upgrade-pick
## RPC so co-op peers stay in sync. Lives as a child of Main holding a `main`
## back-reference (like EnemySpawner/Net); builds its UI into main.ui.

var main: Node

var panel: Control
var god_btn: Button
var no_levelup_btn: Button
var freeze_btn: Button
var immortal_btn: Button
var no_spawn_btn: Button
var fuse_a: OptionButton
var fuse_b: OptionButton
var spawn_select: OptionButton


## F1 handler: show/hide the panel (no-op if it hasn't been built yet).
func toggle() -> void:
	if panel != null:
		panel.visible = not panel.visible


func build() -> void:
	panel = Control.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -276.0
	panel.offset_right = -16.0
	panel.offset_top = 16.0
	panel.offset_bottom = -16.0
	panel.visible = false
	main.ui.add_child(panel)

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 8.0
	scroll.offset_top = 8.0
	scroll.offset_right = -8.0
	scroll.offset_bottom = -8.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	var title := Label.new()
	title.text = "DEBUG (F1)"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	vbox.add_child(title)

	god_btn = Button.new()
	god_btn.text = "God Mode: OFF"
	god_btn.pressed.connect(_toggle_god)
	vbox.add_child(god_btn)

	no_levelup_btn = Button.new()
	no_levelup_btn.text = "No Levelup: OFF"
	no_levelup_btn.pressed.connect(_toggle_no_levelup)
	vbox.add_child(no_levelup_btn)

	freeze_btn = Button.new()
	freeze_btn.text = "Freeze Enemies: OFF"
	freeze_btn.pressed.connect(_toggle_freeze_enemies)
	vbox.add_child(freeze_btn)

	immortal_btn = Button.new()
	immortal_btn.text = "Immortal Enemies: OFF"
	immortal_btn.pressed.connect(_toggle_immortal_enemies)
	vbox.add_child(immortal_btn)

	no_spawn_btn = Button.new()
	no_spawn_btn.text = "Stop Spawning: OFF"
	no_spawn_btn.pressed.connect(_toggle_no_spawn)
	vbox.add_child(no_spawn_btn)

	var levelup_btn := Button.new()
	levelup_btn.text = "Instant Level Up"
	levelup_btn.pressed.connect(_level_up)
	vbox.add_child(levelup_btn)

	var reset_btn := Button.new()
	reset_btn.text = "Reset Weapons + Stats"
	reset_btn.pressed.connect(_reset_loadout)
	vbox.add_child(reset_btn)

	var grant_head := Label.new()
	grant_head.text = "Grant / level weapon"
	grant_head.add_theme_font_size_override("font_size", 14)
	grant_head.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	vbox.add_child(grant_head)

	var grid := GridContainer.new()
	grid.columns = 4
	vbox.add_child(grid)
	for wid in Main.WEAPON_INFO:
		var b := Button.new()
		b.text = wid
		b.add_theme_font_size_override("font_size", 12)
		b.custom_minimum_size = Vector2(56, 26)
		b.pressed.connect(_grant_weapon.bind(wid))
		grid.add_child(b)

	var fuse_head := Label.new()
	fuse_head.text = "Grant fusion"
	fuse_head.add_theme_font_size_override("font_size", 14)
	fuse_head.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	vbox.add_child(fuse_head)

	var fuse_row := HBoxContainer.new()
	vbox.add_child(fuse_row)
	fuse_a = OptionButton.new()
	fuse_b = OptionButton.new()
	for wid in Main.WEAPON_INFO:
		fuse_a.add_item(wid)
		fuse_b.add_item(wid)
	fuse_b.selected = 1
	fuse_row.add_child(fuse_a)
	fuse_row.add_child(fuse_b)
	var fuse_btn := Button.new()
	fuse_btn.text = "Fuse"
	fuse_btn.pressed.connect(_grant_fusion)
	vbox.add_child(fuse_btn)

	var stat_head := Label.new()
	stat_head.text = "Stat up"
	stat_head.add_theme_font_size_override("font_size", 14)
	stat_head.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	vbox.add_child(stat_head)

	var stat_grid := GridContainer.new()
	stat_grid.columns = 4
	vbox.add_child(stat_grid)
	for sid in Main.STAT_INFO:
		var sb := Button.new()
		sb.text = Main.STAT_INFO[sid].label
		sb.add_theme_font_size_override("font_size", 12)
		sb.custom_minimum_size = Vector2(56, 26)
		sb.pressed.connect(_stat_up.bind(sid))
		stat_grid.add_child(sb)

	var spawn_head := Label.new()
	spawn_head.text = "Spawn enemy (host)"
	spawn_head.add_theme_font_size_override("font_size", 14)
	spawn_head.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	vbox.add_child(spawn_head)

	var spawn_row := HBoxContainer.new()
	vbox.add_child(spawn_row)
	spawn_select = OptionButton.new()
	spawn_select.custom_minimum_size = Vector2(170, 26)
	for ty in main.spawner.types:
		var d: Dictionary = ty.data
		spawn_select.add_item("%s (%s T%d)" % [d.get("name", ty.cls), ty.cls, ty.tier])
	spawn_row.add_child(spawn_select)
	var spawn_btn := Button.new()
	spawn_btn.text = "Spawn"
	spawn_btn.pressed.connect(_spawn_enemy)
	spawn_row.add_child(spawn_btn)


func _toggle_god() -> void:
	var p: Player = main.players.get(main.local_id)
	if p == null:
		return
	p.debug_god = not p.debug_god
	god_btn.text = "God Mode: ON" if p.debug_god else "God Mode: OFF"


func _toggle_no_levelup() -> void:
	main.debug_no_levelup = not main.debug_no_levelup
	no_levelup_btn.text = "No Levelup: ON" if main.debug_no_levelup else "No Levelup: OFF"


func _toggle_freeze_enemies() -> void:
	main.debug_freeze_enemies = not main.debug_freeze_enemies
	freeze_btn.text = "Freeze Enemies: ON" if main.debug_freeze_enemies else "Freeze Enemies: OFF"


func _toggle_immortal_enemies() -> void:
	main.debug_immortal_enemies = not main.debug_immortal_enemies
	immortal_btn.text = "Immortal Enemies: ON" if main.debug_immortal_enemies else "Immortal Enemies: OFF"


func _toggle_no_spawn() -> void:
	main.debug_no_spawn = not main.debug_no_spawn
	no_spawn_btn.text = "Stop Spawning: ON" if main.debug_no_spawn else "Stop Spawning: OFF"


## Grants the weapon if the local player doesn't have it yet, otherwise
## levels it up (capped at MAX_WEAPON_LEVEL) — handy for testing fusions.
func _grant_weapon(id: String) -> void:
	var p: Player = main.players.get(main.local_id)
	if p == null:
		return
	var w := p.get_weapon(id)
	if w == null:
		main.net.submit_choice(main.local_id, "learn_" + id)
	elif w.level < Main.MAX_WEAPON_LEVEL:
		main.net.submit_choice(main.local_id, "lv_" + id)


func _stat_up(id: String) -> void:
	if main.players.get(main.local_id) == null:
		return
	main.net.submit_choice(main.local_id, id)


## Strips the local player of every weapon (including the starting bolt) and
## resets every stat multiplier to its starting value — a clean slate for
## re-testing weapons without restarting the run.
func _reset_loadout() -> void:
	var p: Player = main.players.get(main.local_id)
	if p == null:
		return
	for w in p.weapons:
		w.queue_free()
	p.weapons.clear()
	p.power_stat = 1.0   # damage_mult is derived from this each frame
	p.damage_mult = 1.0
	p.rate_mult = 1.0
	p.area_mult = 1.0
	p.duration_mult = 1.0
	p.move_speed = 220.0
	p.pickup_range = 90.0
	p.dash_cooldown = 2.5
	p.stat_levels.clear()
	p.max_hp = 5
	p.hp = mini(p.hp, p.max_hp)
	p.health_changed.emit(p.hp, p.max_hp)


## Force the party to its next level-up pick immediately (host-only — the
## same path real XP gain uses, so picks/sync behave normally).
func _level_up() -> void:
	if not main.is_host() or main.leveling or main.game_over:
		return
	main.xp = main._xp_needed()
	main._maybe_open_picks()


## Host-only: spawns one enemy of the selected type near a player — same path
## as normal spawns (spawner.spawn_enemy), for testing specific classes/tiers.
func _spawn_enemy() -> void:
	if not main.is_host():
		return
	var idx := spawn_select.selected
	if idx < 0 or idx >= main.spawner.types.size():
		return
	var ty: Dictionary = main.spawner.types[idx]
	main.spawner.spawn_enemy(ty.cls, ty.tier)


## Maxes both selected weapons (granting them first if missing) and fuses
## them — signature recipe if one exists, otherwise the generic WeaponFused.
func _grant_fusion() -> void:
	var a := fuse_a.get_item_text(fuse_a.selected)
	var b := fuse_b.get_item_text(fuse_b.selected)
	if a == b:
		return
	var p: Player = main.players.get(main.local_id)
	if p == null:
		return
	for id in [a, b]:
		_grant_weapon(id)
		var w := p.get_weapon(id)
		while w != null and w.level < Main.MAX_WEAPON_LEVEL:
			main.net.submit_choice(main.local_id, "lv_" + id)
			w = p.get_weapon(id)
	main.net.submit_choice(main.local_id, "merge_" + Fusions.key(a, b))
