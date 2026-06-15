class_name GameHud
extends Node
## In-run HUD logic: the per-frame readout refresh (timer/level/kills/xp/hp/dash/
## threat/weapons/stats/allies), off-screen ally arrows, weapon-slot hover tooltips,
## and boss/elite spawn banners. Lives as a child of Main holding a `main`
## back-reference; the HUD node refs themselves stay on main (woven through the
## menu/run flow), so this module reads/writes main.<label> rather than owning them.

var main: Node


## Per-frame HUD refresh (called from main._process).
func update() -> void:
	var me: Player = main.players.get(main.local_id)
	var t := int(main.elapsed)
	main.timer_label.text = "%02d:%02d" % [t / 60, t % 60]
	main.level_label.text = "Lv %d" % main.level
	main.kills_label.text = "Kills %d" % main.kills
	main.xp_bar.value = float(main.xp) / float(maxi(main._current_needed(), 1)) * 100.0
	main.arrows.queue_redraw()
	if main._banner_t > 0.0 and main.banner_label != null:
		main._banner_t -= main.get_process_delta_time()
		var since: float = Main.BANNER_LIFE - main._banner_t
		var a := 1.0
		if since < 0.2:
			a = since / 0.2
		elif main._banner_t < 0.6:
			a = main._banner_t / 0.6
		main.banner_label.modulate.a = clampf(a, 0.0, 1.0)
	# Threat readout: a named, color-coded tier (CALM…NIGHTMARE) the player can parse
	# at a glance, a bar that only ever grows toward NIGHTMARE, and a plain-word note
	# when the climb is accelerating (heat). Display-only — no balance effect.
	var heat: float = main.spawner.heat()
	var diff: float = main.spawner.diff()
	var ti := 0
	for j in Main.THREAT_TIERS.size():
		if diff >= float(Main.THREAT_TIERS[j].at):
			ti = j
	var tier: Dictionary = Main.THREAT_TIERS[ti]
	var cap: float = maxf(float(Main.THREAT_TIERS[Main.THREAT_TIERS.size() - 1].at), 1.0)
	var filled := clampi(int(round(diff / cap * 8.0)), 0, 8)  # monotonic: fills toward NIGHTMARE
	var bar := "▮".repeat(filled) + "▯".repeat(8 - filled)
	var rising := ""
	if heat >= 0.5:
		rising = "   ▲▲ SURGING"
	elif heat >= 0.15:
		rising = "   ▲ rising"
	main.threat_label.text = "THREAT  %s  %s%s" % [tier.name, bar, rising]
	main.threat_label.add_theme_color_override("font_color", tier.color)
	if me == null:
		return
	if me.downed:
		main.hp_label.text = "DOWNED" if main.is_solo() else "DOWNED — ally can revive you"
	else:
		main.hp_label.text = "♥".repeat(maxi(me.hp, 0)) + "♡".repeat(me.max_hp - maxi(me.hp, 0))
	if me.dash_timer <= 0.0:
		main.dash_label.text = "Dash READY"
		main.dash_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.7))
	else:
		main.dash_label.text = "Dash %.1fs" % me.dash_timer
		main.dash_label.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7))
	# Skill slots: each owned weapon is a highlighted, hover-able badge; remaining slots
	# are dim ◇ up to MAX_WEAPONS, with an n/5 count (amber FULL at the cap) — so the
	# 5-slot limit reads at a glance. Hover a slot for that weapon's current stats.
	var wparts := []
	for w in me.weapons:
		wparts.append("[url=%s][bgcolor=#27344c] %s [/bgcolor][/url]" % [w.weapon_id, _weapon_badge(w)])
	for _k in range(me.weapons.size(), Main.MAX_WEAPONS):
		wparts.append("[bgcolor=#161c28][color=#39414f] ◇ [/color][/bgcolor]")
	var w_full: bool = me.weapons.size() >= Main.MAX_WEAPONS
	var w_cnt := "WEAPONS %d/%d%s" % [me.weapons.size(), Main.MAX_WEAPONS, "  FULL" if w_full else ""]
	main.weapons_label.text = "[right][color=#%s]%s[/color]   %s[/right]" \
		% ["ff9a55" if w_full else "6b7488", w_cnt, "  ".join(wparts)]
	# Current stat upgrades, directly under the weapon slots.
	var sparts := []
	for sid in Main.STAT_INFO:
		var slvl := int(me.stat_levels.get(sid, 0))
		if slvl > 0:
			sparts.append(_stat_badge(Main.STAT_INFO[sid], slvl))
	main.stats_label.text = ("[right][color=#6b7488]STATS[/color]   %s[/right]" % "  ".join(sparts)) if not sparts.is_empty() else ""
	if main.weapon_tip.visible and main._tip_weapon_id != "":
		main.weapon_tip.text = _weapon_tip_text(main._tip_weapon_id)  # keep stats live while hovered
	var lines := []
	for pid in main.peer_ids:
		if pid == main.local_id:
			continue
		var p: Player = main.players.get(pid)
		if p == null:
			continue
		var tag := " (away)" if p.disconnected else ""
		if p.downed:
			lines.append("%s  DOWN %d%%%s" % [p.player_name, int(p.revive_progress * 100.0), tag])
		else:
			lines.append("%s  ♥%d/%d%s" % [p.player_name, p.hp, p.max_hp, tag])
	main.allies_label.text = "\n".join(lines)


## Draw callback for the `arrows` Control: off-screen markers pointing at each ally.
func _draw_ally_arrows() -> void:
	if not main.playing:
		return
	var me: Player = main.players.get(main.local_id)
	if me == null:
		return
	var size: Vector2 = main.arrows.get_viewport_rect().size
	var xform: Transform2D = main.get_viewport().get_canvas_transform()
	for pid in main.peer_ids:
		if pid == main.local_id:
			continue
		var p: Player = main.players.get(pid)
		if p == null:
			continue
		var sp: Vector2 = xform * p.global_position
		if Rect2(Vector2.ZERO, size).grow(-24.0).has_point(sp):
			continue
		var c := sp.clamp(Vector2(40.0, 40.0), size - Vector2(40.0, 40.0))
		var dir := (sp - c).normalized()
		if dir == Vector2.ZERO:
			continue
		var col := Player.COLORS[p.color_idx % Player.COLORS.size()]
		var tip := c + dir * 16.0
		var side := dir.orthogonal() * 9.0
		main.arrows.draw_polygon(PackedVector2Array([tip, c - dir * 4.0 + side, c - dir * 4.0 - side]),
			PackedColorArray([col]))


## BBCode badge for one leveled stat (shown in the top-right stats row): the stat's
## color-coded icon glyph + how many times it's been picked.
func _stat_badge(info: Dictionary, lvl: int) -> String:
	return "[color=#%s]%s[/color]×%d" % [info.color.to_html(false), info.icon, lvl]


## A weapon slot was hovered: remember which weapon and show its current-stats tooltip.
## update() refreshes the text each frame so the numbers stay live while hovered.
func _on_weapon_hover(meta) -> void:
	main._tip_weapon_id = str(meta)
	main.weapon_tip.text = _weapon_tip_text(main._tip_weapon_id)
	main.weapon_tip.visible = main._tip_weapon_id != ""


func _on_weapon_unhover(_meta) -> void:
	main._tip_weapon_id = ""
	main.weapon_tip.visible = false


## Current effective stats of one owned weapon, for the hover tooltip. Effective damage
## and cadence come from WeaponConfig.BASE scaled by level + the local player's Power/Haste
## (cd = recurring cooldown/tick/re-hit per BASE's contract). Fusions have no BASE row, so
## they show a qualitative line instead of fabricated numbers.
func _weapon_tip_text(id: String) -> String:
	var me: Player = main.players.get(main.local_id)
	if me == null:
		return ""
	var w = me.get_weapon(id)
	if w == null:
		return ""
	var lines := ["[color=#cdd6e6]%s[/color]  [color=#9aa4b8]Lv %d[/color]" % [w.display_name, w.level]]
	if WeaponConfig.BASE.has(id):
		var b: Dictionary = WeaponConfig.BASE[id]
		var dmg: float = b.dmg * (1.0 + b.growth * (w.level - 1)) * me.damage_mult
		var cd: float = b.cd * me.rate_mult
		lines.append("[color=#ff9a8a]DMG %.1f[/color]   [color=#9fd0ff]every %.2fs[/color]" % [dmg, cd])
	else:
		lines.append("[color=#ffd479]fusion[/color] [color=#9aa4b8]— scales with your stats[/color]")
	if Main.WEAPON_INFO.has(id):
		lines.append("[color=#7e8aa0]%s[/color]" % Main.WEAPON_INFO[id].level)
	return "[right]" + "\n".join(lines) + "[/right]"


## Compact on-screen badge for an owned weapon: a colored ◆ + 3-char code + superscript level.
## Base weapons use WEAPON_ICON; fusions fall back to gold initials of their display name.
func _weapon_badge(w) -> String:
	var code: String
	var col: String
	if Main.WEAPON_ICON.has(w.weapon_id):
		code = Main.WEAPON_ICON[w.weapon_id][0]
		col = Main.WEAPON_ICON[w.weapon_id][1]
	else:
		code = _fusion_short(w.display_name)
		col = "ffd479"  # fusion = gold
	var lv := clampi(w.level, 0, Main.SUP.size() - 1)
	return "[color=#%s]◆%s[/color]%s" % [col, code, Main.SUP[lv]]


## Up-to-3-char code for a fusion: initials of each word, or first letters if it's one word.
func _fusion_short(dname: String) -> String:
	var s := ""
	for word in dname.split(" ", false):
		if not word.is_empty():
			s += word.substr(0, 1)
	if s.length() < 2:
		s = dname.replace(" ", "")
	return s.to_upper().substr(0, 3)


func show_banner(text: String, is_boss: bool) -> void:
	if main.banner_label == null:
		return
	main.banner_label.text = ("BOSS:  %s" % text) if is_boss else ("ELITE:  %s" % text)
	main.banner_label.add_theme_color_override("font_color",
		Color(1.0, 0.3, 0.3) if is_boss else Color(1.0, 0.78, 0.35))
	main.banner_label.add_theme_font_size_override("font_size", 54 if is_boss else 42)
	main._banner_t = Main.BANNER_LIFE


## Host: announce a boss / mini-boss (elite) spawn — locally and to all clients.
func announce_boss(text: String, is_boss: bool) -> void:
	show_banner(text, is_boss)
	main.net.send_announce(text, is_boss)
