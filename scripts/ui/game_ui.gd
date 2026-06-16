class_name GameUI
extends Node
## UI construction: builds the entire CanvasLayer UI tree (HUD root, overlays,
## menu/lobby/pause/level/end/countdown panels, codex tabs, profile panel) into
## main.ui. Lives as a child of Main holding a `main` back-reference (typed `Main`
## so the compiler statically checks every main.<member> reference); the node-ref
## vars themselves stay declared on main.gd — these build funcs ASSIGN to them.

var main: Main


func build() -> void:
	main.ui = CanvasLayer.new()
	main.add_child(main.ui)

	main.hud_root = Control.new()
	main.hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	main.hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.ui.add_child(main.hud_root)

	main.xp_bar = ProgressBar.new()
	main.xp_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	main.xp_bar.offset_bottom = 12.0
	main.xp_bar.show_percentage = false
	main.hud_root.add_child(main.xp_bar)

	main.hp_label = _make_label(Vector2(16, 20), 30, Color(1.0, 0.35, 0.4))
	main.timer_label = _make_label(Vector2(600, 20), 30, Color.WHITE)
	main.level_label = _make_label(Vector2(16, 58), 22, Color(0.8, 0.85, 1.0))
	main.kills_label = _make_label(Vector2(16, 86), 22, Color(0.8, 0.85, 1.0))
	main.dash_label = _make_label(Vector2(16, 114), 22, Color(0.5, 1.0, 0.7))
	main.threat_label = _make_label(Vector2(540, 58), 22, Color(0.6, 0.65, 0.75))
	main.allies_label = RichTextLabel.new()  # BBCode so each ally name shows in their own colour
	main.allies_label.bbcode_enabled = true
	main.allies_label.fit_content = true
	main.allies_label.scroll_active = false
	main.allies_label.position = Vector2(16, 146)
	main.allies_label.custom_minimum_size = Vector2(380, 0)
	main.allies_label.add_theme_font_size_override("normal_font_size", 20)
	main.hud_root.add_child(main.allies_label)
	main.weapons_label = RichTextLabel.new()
	main.weapons_label.bbcode_enabled = true
	main.weapons_label.scroll_active = false
	main.weapons_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	main.weapons_label.mouse_filter = Control.MOUSE_FILTER_PASS  # PASS so [url] slot hover fires
	main.weapons_label.meta_underlined = false
	main.weapons_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	main.weapons_label.offset_left = -600.0
	main.weapons_label.offset_right = -16.0
	main.weapons_label.offset_top = 16.0
	main.weapons_label.offset_bottom = 78.0
	main.weapons_label.add_theme_font_size_override("normal_font_size", 20)
	main.weapons_label.meta_hover_started.connect(main.hud._on_weapon_hover)
	main.weapons_label.meta_hover_ended.connect(main.hud._on_weapon_unhover)
	main.hud_root.add_child(main.weapons_label)

	main.stats_label = RichTextLabel.new()
	main.stats_label.bbcode_enabled = true
	main.stats_label.scroll_active = false
	main.stats_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	main.stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.stats_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	main.stats_label.offset_left = -600.0
	main.stats_label.offset_right = -16.0
	main.stats_label.offset_top = 80.0
	main.stats_label.offset_bottom = 116.0
	main.stats_label.add_theme_font_size_override("normal_font_size", 18)
	main.hud_root.add_child(main.stats_label)

	main.weapon_tip = RichTextLabel.new()
	main.weapon_tip.bbcode_enabled = true
	main.weapon_tip.scroll_active = false
	main.weapon_tip.fit_content = true
	main.weapon_tip.autowrap_mode = TextServer.AUTOWRAP_OFF
	main.weapon_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.weapon_tip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	main.weapon_tip.offset_left = -600.0
	main.weapon_tip.offset_right = -16.0
	main.weapon_tip.offset_top = 120.0
	main.weapon_tip.add_theme_font_size_override("normal_font_size", 16)
	main.weapon_tip.visible = false
	main.hud_root.add_child(main.weapon_tip)

	main.hint_label = _make_label(Vector2(16, 690), 16, Color(0.5, 0.55, 0.65))
	main.hint_label.text = Main.HINT_COOP
	main.banner_label = _make_label(Vector2.ZERO, 46, Color.WHITE)
	main.banner_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	main.banner_label.offset_top = 90.0  # centered, just below the difficulty/threat readout (not over the left HUD list)
	main.banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main.banner_label.modulate.a = 0.0

	main.arrows = Control.new()
	main.arrows.set_anchors_preset(Control.PRESET_FULL_RECT)
	main.arrows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.arrows.draw.connect(main.hud._draw_ally_arrows)
	main.hud_root.add_child(main.arrows)

	_build_level_panel()
	_build_end_panel()
	_build_pause_panel()
	_build_ingame_menu_panel()
	_build_countdown_panel()
	_build_menu()
	_build_lobby_panel()
	_build_stats_panel()
	if OS.is_debug_build():
		main.debug.build()


func _build_stats_panel() -> void:
	# Anchor to bottom-left so content grows upward and never falls off screen.
	main.stats_panel = Control.new()
	main.stats_panel.anchor_left = 0.0
	main.stats_panel.anchor_top = 1.0
	main.stats_panel.anchor_right = 0.0
	main.stats_panel.anchor_bottom = 1.0
	main.stats_panel.offset_left = 16.0
	main.stats_panel.offset_right = 330.0   # 314 px wide
	main.stats_panel.offset_bottom = -72.0  # sits above the hint label
	main.stats_panel.offset_top = -472.0    # 400 px tall
	main.stats_panel.visible = false
	main.hud_root.add_child(main.stats_panel)
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.72)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	main.stats_panel.add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 8.0
	scroll.offset_top = 8.0
	scroll.offset_right = -8.0
	scroll.offset_bottom = -8.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.stats_panel.add_child(scroll)
	main.stats_label_dmg = RichTextLabel.new()
	main.stats_label_dmg.bbcode_enabled = true
	main.stats_label_dmg.fit_content = true
	main.stats_label_dmg.scroll_active = false
	main.stats_label_dmg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.stats_label_dmg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.stats_label_dmg.add_theme_font_size_override("normal_font_size", 17)
	scroll.add_child(main.stats_label_dmg)


func _make_label(pos: Vector2, size: int, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	main.hud_root.add_child(l)
	return l


func _make_overlay() -> Array:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	main.ui.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)
	return [root, vbox]


func _build_level_panel() -> void:
	var parts := _make_overlay()
	main.level_panel = parts[0]
	var vbox: VBoxContainer = parts[1]
	main.panel_title = Label.new()
	main.panel_title.add_theme_font_size_override("font_size", 34)
	main.panel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(main.panel_title)
	for i in Main.MAX_CHOICES:
		var b := Button.new()
		b.custom_minimum_size = Vector2(640, 56)
		b.add_theme_font_size_override("font_size", 21)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.clip_text = false
		b.pressed.connect(main._choose_upgrade.bind(i))
		vbox.add_child(b)
		main.choice_buttons.append(b)


func _build_end_panel() -> void:
	var parts := _make_overlay()
	main.end_panel = parts[0]
	var vbox: VBoxContainer = parts[1]
	main.end_title = Label.new()
	main.end_title.add_theme_font_size_override("font_size", 52)
	main.end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(main.end_title)
	main.end_stats = Label.new()
	main.end_stats.add_theme_font_size_override("font_size", 24)
	main.end_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(main.end_stats)
	main.scoreboard_box = GridContainer.new()
	main.scoreboard_box.columns = 5
	main.scoreboard_box.add_theme_constant_override("h_separation", 24)
	main.scoreboard_box.add_theme_constant_override("v_separation", 4)
	vbox.add_child(main.scoreboard_box)
	main.end_hint = Label.new()
	main.end_hint.add_theme_font_size_override("font_size", 20)
	main.end_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(main.end_hint)


func _build_pause_panel() -> void:
	var parts := _make_overlay()
	main.pause_panel = parts[0]
	var vbox: VBoxContainer = parts[1]
	var l := Label.new()
	l.text = "PAUSED"
	l.add_theme_font_size_override("font_size", 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(l)

	var loadout_head := Label.new()
	loadout_head.text = "YOUR LOADOUT"
	loadout_head.add_theme_font_size_override("font_size", 20)
	loadout_head.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	loadout_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(loadout_head)
	main.pause_loadout = Label.new()
	main.pause_loadout.add_theme_font_size_override("font_size", 20)
	main.pause_loadout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(main.pause_loadout)

	var roster_head := Label.new()
	roster_head.text = "ARSENAL"
	roster_head.add_theme_font_size_override("font_size", 20)
	roster_head.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	roster_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(roster_head)
	main.pause_roster = Label.new()
	main.pause_roster.add_theme_font_size_override("font_size", 17)
	main.pause_roster.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(main.pause_roster)

	var foot := Label.new()
	foot.text = "ESC resume  ·  M main menu"
	foot.add_theme_font_size_override("font_size", 16)
	foot.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(foot)


func _build_ingame_menu_panel() -> void:
	var parts := _make_overlay()
	main.ingame_menu_panel = parts[0]
	var vbox: VBoxContainer = parts[1]
	var l := Label.new()
	l.text = "MENU"
	l.add_theme_font_size_override("font_size", 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(l)
	# nav breadcrumb for the hub tabs (skill/monster codex, settings)
	main.ingame_menu_hint = Label.new()
	main.ingame_menu_hint.add_theme_font_size_override("font_size", 18)
	main.ingame_menu_hint.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	main.ingame_menu_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(main.ingame_menu_hint)
	# skill / monster codex body — hidden (and skipped by the VBox layout) until a tab opens
	main.codex_body = RichTextLabel.new()
	main.codex_body.bbcode_enabled = true
	main.codex_body.scroll_active = true
	main.codex_body.custom_minimum_size = Vector2(840, 480)
	main.codex_body.add_theme_font_size_override("normal_font_size", 15)
	main.codex_body.add_theme_font_size_override("bold_font_size", 16)
	main.codex_body.visible = false
	vbox.add_child(main.codex_body)
	var foot := Label.new()
	foot.text = "ESC resume   ·   C skill codex   ·   V monster codex   ·   O settings   ·   L leave game"
	foot.add_theme_font_size_override("font_size", 16)
	foot.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(foot)


## Open a codex tab inside the hub: swap the menu body for a scrollable list + breadcrumb.
## C = skills, V = monsters; ESC (or _force_close) backs out via _close_codex.
func _show_codex(kind: String) -> void:
	main.codex_view = kind
	if kind == "skills":
		main.ingame_menu_hint.text = "SKILL CODEX      V monsters  ·  ESC back"
		main.codex_body.text = _skill_codex_bbcode()
	else:
		main.ingame_menu_hint.text = "MONSTER CODEX      C skills  ·  ESC back"
		main.codex_body.text = _monster_codex_bbcode()
	main.codex_body.visible = true
	main.codex_body.scroll_to_line(0)


func _close_codex() -> void:
	main.codex_view = ""
	if main.codex_body != null:
		main.codex_body.visible = false
		main.codex_body.text = ""
	if main.ingame_menu_hint != null:
		main.ingame_menu_hint.text = ""


## Every weapon (with its HUD badge) + the stats, each with a one-line description.
func _skill_codex_bbcode() -> String:
	var s := "[b]WEAPONS[/b]      max one, then merge two maxed weapons into a fusion\n\n"
	for wid in Main.WEAPON_INFO:
		var info: Dictionary = Main.WEAPON_INFO[wid]
		var ic: Array = Main.WEAPON_ICON.get(wid, ["?", "ffffff"])
		s += "[color=#%s]◆%s[/color]  [b]%s[/b] — %s\n" % [ic[1], ic[0], info.name, info.learn]
	s += "\n[b]STATS[/b]      stack with every level-up\n\n"
	var stat_desc := {
		"Power": "more weapon damage", "Haste": "attack faster",
		"Area": "bigger blasts, reach and projectiles", "Duration": "effects last longer",
		"Speed": "move faster", "Vitality": "+1 max health",
		"Magnet": "wider pickup range", "Dash": "shorter dash cooldown",
	}
	for sid in Main.STAT_INFO:
		var nm: String = Main.STAT_INFO[sid]
		s += "•  [b]%s[/b] — %s\n" % [nm, stat_desc.get(nm, "")]
	return s


## Every enemy archetype with its tier names (Grunt → Bruiser → …), colored by the class,
## and a one-line behavior note. Built from EnemyConfig.CLASSES so new classes appear here too.
func _monster_codex_bbcode() -> String:
	var blurb := {
		"brawler": "baseline chasers", "rusher": "fast, fragile darters",
		"tank": "huge, slow, heavy hits; immune to pull", "caster": "ranged, telegraphed strikes",
		"warden": "armored — shrugs off part of every hit", "burster": "spits a ring of shards on death",
		"shard": "a burster's bullet — phases through, expires", "sentinel": "phases an unbreakable shield — strike between",
		"wisp": "immune to ENERGY; drifts unpredictably", "bouncer": "ricochets, phases, can't be interrupted",
		"disruptor": "zones that slow you and lock your dash", "defiler": "lays lingering disrupt fields on the ground",
		"elite": "tanky special — always drops a chest", "boss": "periodic giant — a unique gimmick + map-wide slams",
	}
	var s := "[b]ENEMIES[/b]      tiers escalate with time, level and difficulty\n\n"
	for cls in EnemyConfig.CLASSES:
		var tiers: Array = EnemyConfig.CLASSES[cls]
		var names := []
		for t in tiers:
			names.append(t.name)
		var col: Color = tiers[0].col
		s += "[color=#%s]●[/color]  [b]%s[/b] — %s\n" % [col.to_html(false), " → ".join(names), blurb.get(cls, "")]
	return s


func _build_countdown_panel() -> void:
	var parts := _make_overlay()
	main.countdown_panel = parts[0]
	var vbox: VBoxContainer = parts[1]
	var head := Label.new()
	head.text = "RESUMING"
	head.add_theme_font_size_override("font_size", 24)
	head.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(head)
	main.countdown_label = Label.new()
	main.countdown_label.add_theme_font_size_override("font_size", 96)
	main.countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(main.countdown_label)


func _refresh_pause_roster() -> void:
	var me: Player = main.players.get(main.local_id)
	if me == null:
		return
	var loadout := []
	for w in me.weapons:
		loadout.append("%s — Lv %d" % [w.display_name, w.level])
	main.pause_loadout.text = "\n".join(loadout) if not loadout.is_empty() else "—"

	# which base weapons are absorbed into a fusion
	var fused_ids := {}
	for w in me.weapons:
		if w is WeaponFused:
			for c in w.components:
				fused_ids[c.weapon_id] = true

	var lines := []
	var row := []
	var i := 0
	for wid in Main.WEAPON_INFO:
		var status: String
		var owned := me.get_weapon(wid)
		if owned != null:
			status = "Lv %d" % owned.level
		elif fused_ids.has(wid):
			status = "fused"
		else:
			status = "—"
		row.append((Main.WEAPON_INFO[wid].name as String).rpad(17) + status)
		i += 1
		if row.size() == 2:  # two weapons per line
			lines.append("   ".join(row))
			row = []
	if not row.is_empty():
		lines.append("   ".join(row))
	main.pause_roster.text = "\n".join(lines)


## A label + a button that cycles an option; `get_text` returns the current value
## string, `advance` steps to the next. The button relabels itself on each press.
func _make_cycler(parent: Node, label: String, get_text: Callable, advance: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var l := Label.new()
	l.text = label
	l.add_theme_font_size_override("font_size", 18)
	l.custom_minimum_size = Vector2(220, 38)
	row.add_child(l)
	var b := Button.new()
	b.custom_minimum_size = Vector2(132, 38)
	b.add_theme_font_size_override("font_size", 18)
	b.text = get_text.call()
	b.pressed.connect(func():
		advance.call()
		b.text = get_text.call())
	row.add_child(b)


## Left panel on the main menu: persistent name/color/shape, used whenever this
## player solos, hosts, or joins a session -- no separate lobby appearance step.
func _build_profile_panel(parent: Node) -> void:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(220, 0)
	box.add_theme_constant_override("separation", 12)
	parent.add_child(box)

	var head := Label.new()
	head.text = "PROFILE"
	head.add_theme_font_size_override("font_size", 18)
	head.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)

	main.profile_preview_label = Label.new()
	main.profile_preview_label.custom_minimum_size = Vector2(0, 64)
	main.profile_preview_label.add_theme_font_size_override("font_size", 48)
	main.profile_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main.profile_preview_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(main.profile_preview_label)

	main.profile_name_edit = LineEdit.new()
	main.profile_name_edit.custom_minimum_size = Vector2(0, 44)
	main.profile_name_edit.add_theme_font_size_override("font_size", 20)
	main.profile_name_edit.max_length = 16
	main.profile_name_edit.text = main.profile_name
	main.profile_name_edit.text_submitted.connect(func(_t): main._on_profile_appearance_changed())
	main.profile_name_edit.focus_exited.connect(main._on_profile_appearance_changed)
	box.add_child(main.profile_name_edit)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 8)
	box.add_child(btn_row)

	var color_btn := Button.new()
	color_btn.text = "Color"
	color_btn.custom_minimum_size = Vector2(100, 44)
	color_btn.add_theme_font_size_override("font_size", 18)
	color_btn.pressed.connect(main._on_profile_color_pressed)
	btn_row.add_child(color_btn)

	var shape_btn := Button.new()
	shape_btn.text = "Shape"
	shape_btn.custom_minimum_size = Vector2(100, 44)
	shape_btn.add_theme_font_size_override("font_size", 18)
	shape_btn.pressed.connect(main._on_profile_shape_pressed)
	btn_row.add_child(shape_btn)

	main._refresh_profile_preview()


func _build_menu() -> void:
	var parts := _make_overlay()
	main.menu_panel = parts[0]
	main.menu_panel.visible = true
	var vbox: VBoxContainer = parts[1]

	# Profile panel: a fixed strip on the left edge of the screen, independent of
	# the centered menu content -- doesn't push the main buttons off-center.
	var profile_strip := Control.new()
	profile_strip.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	profile_strip.offset_right = 260
	main.menu_panel.add_child(profile_strip)
	var profile_center := CenterContainer.new()
	profile_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	profile_strip.add_child(profile_center)
	_build_profile_panel(profile_center)

	var title := Label.new()
	title.text = "NICESWARM"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "co-op arena survival   ·   v. %s (%s)" % [Main.VERSION, BuildVersion.commit_label()]
	# Mark the debug exe (an exported debug-template build) so bug reports name the right build.
	# Gated on has_feature("template") so the editor — also is_debug_build() — isn't tagged.
	if OS.has_feature("template") and OS.is_debug_build():
		sub.text += "   ·   debug"
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)

	# Update notice (hidden until UpdateCheck finds a newer published build).
	main.update_banner = VBoxContainer.new()
	main.update_banner.visible = false
	main.update_banner.add_theme_constant_override("separation", 4)
	vbox.add_child(main.update_banner)
	var up_label := Label.new()
	up_label.text = "⬆  A newer build is available on GitHub"
	up_label.add_theme_font_size_override("font_size", 18)
	up_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	up_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main.update_banner.add_child(up_label)
	var up_row := HBoxContainer.new()
	up_row.alignment = BoxContainer.ALIGNMENT_CENTER
	up_row.add_theme_constant_override("separation", 8)
	main.update_banner.add_child(up_row)
	var up_get := Button.new()
	up_get.text = "Get Update"
	up_get.add_theme_font_size_override("font_size", 18)
	up_get.pressed.connect(main._on_update_get_pressed)
	up_row.add_child(up_get)
	var up_skip := Button.new()
	up_skip.text = "Skip"
	up_skip.add_theme_font_size_override("font_size", 18)
	up_skip.pressed.connect(main._on_update_skip_pressed)
	up_row.add_child(up_skip)

	var solo := Button.new()
	solo.text = "Play Solo"
	solo.custom_minimum_size = Vector2(360, 52)
	solo.add_theme_font_size_override("font_size", 22)
	solo.pressed.connect(main._on_solo_pressed)
	vbox.add_child(solo)

	var host := Button.new()
	host.text = "Host Co-op"
	host.custom_minimum_size = Vector2(360, 52)
	host.add_theme_font_size_override("font_size", 22)
	host.pressed.connect(main._on_host_pressed)
	vbox.add_child(host)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vbox.add_child(row)
	main.ip_edit = LineEdit.new()
	main.ip_edit.text = "127.0.0.1"
	main.ip_edit.custom_minimum_size = Vector2(252, 52)
	main.ip_edit.add_theme_font_size_override("font_size", 20)
	row.add_child(main.ip_edit)
	var join := Button.new()
	join.text = "Join"
	join.custom_minimum_size = Vector2(100, 52)
	join.add_theme_font_size_override("font_size", 22)
	join.pressed.connect(main._on_join_pressed)
	row.add_child(join)

	var port_row := HBoxContainer.new()
	port_row.add_theme_constant_override("separation", 8)
	vbox.add_child(port_row)
	var port_label := Label.new()
	port_label.text = "Port"
	port_label.add_theme_font_size_override("font_size", 20)
	port_label.custom_minimum_size = Vector2(100, 40)
	port_row.add_child(port_label)
	main.port_edit = LineEdit.new()
	main.port_edit.text = str(Net.PORT)
	main.port_edit.custom_minimum_size = Vector2(252, 40)
	main.port_edit.add_theme_font_size_override("font_size", 20)
	port_row.add_child(main.port_edit)

	# difficulty config cyclers (used by Solo and Host)
	_make_cycler(vbox, "Options / level-up", func(): return str(Main.CHOICES_OPTS[main.cfg_choices_i]),
		func(): main.cfg_choices_i = (main.cfg_choices_i + 1) % Main.CHOICES_OPTS.size())
	_make_cycler(vbox, "XP rate", func(): return str(Main.XP_OPTS[main.cfg_xp_i]) + "x",
		func(): main.cfg_xp_i = (main.cfg_xp_i + 1) % Main.XP_OPTS.size())
	_make_cycler(vbox, "Enemy scale", func(): return str(Main.SCALE_OPTS[main.cfg_scale_i]) + "x",
		func(): main.cfg_scale_i = (main.cfg_scale_i + 1) % Main.SCALE_OPTS.size())

	main.status_label = Label.new()
	main.status_label.add_theme_font_size_override("font_size", 18)
	main.status_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	main.status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(main.status_label)


## Shown after a successful host/join, before the run starts: connection status,
## your name/color/shape, the roster of everyone in the session, the host's game
## config (read-only for clients, live-editable for the host), and start/leave.
func _build_lobby_panel() -> void:
	var parts := _make_overlay()
	main.lobby_panel = parts[0]
	main.lobby_panel.visible = false
	var vbox: VBoxContainer = parts[1]

	var title := Label.new()
	title.text = "LOBBY"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	main.lobby_status_label = Label.new()
	main.lobby_status_label.add_theme_font_size_override("font_size", 18)
	main.lobby_status_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	main.lobby_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(main.lobby_status_label)

	# Two columns: left (appearance + roster) expands to fill, right (config)
	# shrinks to fit its content. custom_minimum_size on `columns` gives the
	# left column extra width to expand into beyond its own natural minimum.
	var columns := HBoxContainer.new()
	columns.custom_minimum_size = Vector2(900, 0)
	columns.add_theme_constant_override("separation", 24)
	vbox.add_child(columns)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 16)
	columns.add_child(left)

	var players_head := Label.new()
	players_head.text = "PLAYERS"
	players_head.add_theme_font_size_override("font_size", 18)
	players_head.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	players_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(players_head)

	main.lobby_roster_box = VBoxContainer.new()
	main.lobby_roster_box.add_theme_constant_override("separation", 4)
	left.add_child(main.lobby_roster_box)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	columns.add_child(right)

	var config_head := Label.new()
	config_head.text = "GAME CONFIG"
	config_head.add_theme_font_size_override("font_size", 18)
	config_head.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	config_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(config_head)

	main.lobby_config_box = VBoxContainer.new()
	main.lobby_config_box.add_theme_constant_override("separation", 4)
	right.add_child(main.lobby_config_box)

	main.lobby_start_btn = Button.new()
	main.lobby_start_btn.text = "Start Game"
	main.lobby_start_btn.custom_minimum_size = Vector2(360, 52)
	main.lobby_start_btn.add_theme_font_size_override("font_size", 22)
	main.lobby_start_btn.visible = false
	main.lobby_start_btn.pressed.connect(main._on_start_pressed)
	vbox.add_child(main.lobby_start_btn)

	var leave_btn := Button.new()
	leave_btn.text = "Leave Lobby"
	leave_btn.custom_minimum_size = Vector2(360, 52)
	leave_btn.add_theme_font_size_override("font_size", 22)
	leave_btn.pressed.connect(main._on_lobby_leave_pressed)
	vbox.add_child(leave_btn)
