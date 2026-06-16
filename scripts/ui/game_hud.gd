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
	if main.stats_panel != null and main.stats_panel.visible:
		_update_stats_panel(me)
	var lines := []
	for pid in main.peer_ids:
		if pid == main.local_id:
			continue
		var p: Player = main.players.get(pid)
		if p == null:
			continue
		var col: Color = Player.COLORS[p.color_idx % Player.COLORS.size()]
		var glyph: String = Player.shape_glyph(p.shape_idx)  # character marker
		var ping := int(main.net_pings.get(pid, 0))
		var ping_s := ("  %dms" % ping) if ping > 0 else ""
		var tag := "  (away)" if p.disconnected else ""
		var status := ("DOWN %d%%" % int(p.revive_progress * 100.0)) if p.downed else "♥%d/%d" % [p.hp, p.max_hp]
		# colour the glyph + name in the ally's own colour; hp/ping stay neutral
		lines.append("[color=#%s]%s %s[/color]  %s%s%s" % [col.to_html(false), glyph, p.player_name, status, ping_s, tag])
	# Self ping at the bottom of the list (co-op only — solo has no network round-trip).
	# net_pings[local_id] is the host-measured RTT to us on a client; on the host it's 0,
	# so we label our own row "host" instead of "0ms".
	if main.net != null and main.net.active:
		var my_col: Color = Player.COLORS[me.color_idx % Player.COLORS.size()]
		var my_glyph: String = Player.shape_glyph(me.shape_idx)
		var my_ping := int(main.net_pings.get(main.local_id, 0))
		var my_ping_s := "host" if main.is_host() else "%dms" % my_ping
		var my_status := ("DOWN %d%%" % int(me.revive_progress * 100.0)) if me.downed else "♥%d/%d" % [me.hp, me.max_hp]
		lines.append("[color=#%s]%s %s[/color]  %s  %s  (you)" % [my_col.to_html(false), my_glyph, me.player_name, my_status, my_ping_s])
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


## Full live stat block for one owned weapon, for the hover tooltip — shown for EVERY
## weapon, base or fusion. Base weapons expose effective per-hit DMG + cadence from
## WeaponConfig.BASE (scaled by level + the player's Power/Haste). Fusions have no BASE
## row (tier-1 are monolithic classes, tier-2+ are WeaponFused), so instead of fabricating
## per-hit numbers they show their real live DPS + total dealt — tracked universally on
## every WeaponBase. Every weapon also shows live DPS/total and the four build-wide stat
## axes, so the player can read any slot's contribution at a glance.
func _weapon_tip_text(id: String) -> String:
	var me: Player = main.players.get(main.local_id)
	if me == null:
		return ""
	var w = me.get_weapon(id)
	if w == null:
		return ""
	# Header: name + level + fusion-tier badge.
	var head := "[color=#cdd6e6]%s[/color]  [color=#9aa4b8]Lv %d[/color]" % [w.display_name, w.level]
	if w.tier > 0:
		head += "  [color=#ffd479]◆T%d[/color]" % w.tier
	var lines := [head]
	# Per-hit DMG + cadence: only base weapons carry a BASE row to derive these from.
	if WeaponConfig.BASE.has(id):
		var b: Dictionary = WeaponConfig.BASE[id]
		var dmg: float = b.dmg * (1.0 + b.growth * (w.level - 1)) * me.damage_mult
		var cd: float = b.cd * me.rate_mult
		lines.append("[color=#ff9a8a]DMG %.1f[/color]   [color=#9fd0ff]every %.2fs[/color]" % [dmg, cd])
	else:
		lines.append("[color=#ffd479]fusion[/color] [color=#9aa4b8]— combined attack[/color]")
	# Live output — universal, works for base weapons AND fusions (sums components).
	lines.append("[color=#ff9a8a]DPS %s/s[/color]   [color=#7e8aa0]total %s[/color]" \
		% [_fmt_dmg(_weapon_dps(w)), _fmt_dmg(_weapon_dmg(w))])
	# Build-wide stat axes (global to the player, the same for every weapon you own).
	lines.append("[color=#6b7488]Your build:[/color]  [color=#ff6f6a]Pwr ×%.2f[/color]  [color=#ffd966]Spd ×%.2f[/color]  [color=#8cb4ff]Area ×%.2f[/color]  [color=#9be09b]Dur ×%.2f[/color]" \
		% [me.damage_mult, 1.0 / maxf(me.rate_mult, 0.01), me.area_mult, me.duration_mult])
	# Behavior blurb: base weapons use WEAPON_INFO; fusions use their Fusions.INFO desc.
	if Main.WEAPON_INFO.has(id):
		lines.append("[color=#7e8aa0]%s[/color]" % Main.WEAPON_INFO[id].level)
	else:
		var desc := _fusion_desc(w)
		if desc != "":
			lines.append("[color=#7e8aa0]%s[/color]" % desc)
	return "[right]" + "\n".join(lines) + "[/right]"


## Behavior text for a fusion: its Fusions.INFO description (signature recipe), or a
## component list for a generic/deep WeaponFused that has no signature entry.
func _fusion_desc(w) -> String:
	if w is WeaponFused:
		var parts := []
		for c in w.get_children():
			if c is WeaponBase:
				parts.append("%s Lv%d" % [c.display_name, c.level])
		return "combines " + " + ".join(parts) if not parts.is_empty() else ""
	# Signature fusion: recover its INFO desc by matching display_name.
	for k in Fusions.INFO:
		if Fusions.INFO[k].name == w.display_name:
			return Fusions.INFO[k].desc
	return ""


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


func _update_stats_panel(me: Player) -> void:
	if me == null or me.weapons.is_empty():
		main.stats_label_dmg.text = "[color=#6b7488]No weapons[/color]"
		return
	var show_dps: bool = main.stats_mode == 2
	var total := 0.0
	for w in me.weapons:
		total += _weapon_dmg(w)
	var title := "[b][color=#cdd6e6]%s[/color][/b]  [color=#39414f][TAB][/color]\n" \
		% ("DPS (1s)" if show_dps else "DAMAGE STATS")
	var lines := title
	for w in me.weapons:
		var dmg := _weapon_dmg(w)
		var pct := int(dmg / maxf(total, 1.0) * 100.0)
		var bar := "▮".repeat(pct / 10) + "▯".repeat(10 - pct / 10)
		var value := _fmt_dmg(_weapon_dps(w)) + "/s" if show_dps else _fmt_dmg(dmg)
		lines += "[color=#cdd6e6]%s[/color]  [color=#ff9a8a]%s[/color]  [color=#6b7488]%s %d%%[/color]\n" \
			% [w.display_name, value, bar, pct]
	if main._burn_total > 0.0 or main.burn_dps_val > 0.0:
		var burn_value := _fmt_dmg(main.burn_dps_val) + "/s" if show_dps else _fmt_dmg(main._burn_total)
		lines += "[color=#ff7755]Burn[/color]  [color=#ff9a8a]%s[/color]\n" % burn_value
	main.stats_label_dmg.text = lines


func _weapon_dmg(w: WeaponBase) -> float:
	if w is WeaponFused:
		var s := 0.0
		for c in w.get_children():
			if c is WeaponBase:
				s += c.damage_dealt
		return s
	return w.damage_dealt


func _weapon_dps(w: WeaponBase) -> float:
	if w is WeaponFused:
		var s := 0.0
		for c in w.get_children():
			if c is WeaponBase:
				s += c.dps
		return s
	return w.dps


func _fmt_dmg(d: float) -> String:
	if d >= 1000.0:
		return "%.1fk" % (d / 1000.0)
	return str(int(d))
