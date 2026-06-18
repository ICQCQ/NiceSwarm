class_name GameHud
extends Node
## In-run HUD logic: the per-frame readout refresh (timer/level/kills/xp/hp/dash/
## threat/weapons/stats/allies), off-screen ally arrows, weapon-slot hover tooltips,
## and boss/elite spawn banners. Lives as a child of Main holding a `main`
## back-reference; the HUD node refs themselves stay on main (woven through the
## menu/run flow), so this module reads/writes main.<label> rather than owning them.

var main: Node

# Live ranking panel state
var _rank_rows: Dictionary = {}   # pid -> RichTextLabel
var _rank_order: Array = []       # pids sorted by damage, current frame
var _rank_tweens: Dictionary = {} # pid -> Tween (in-flight slide animation)
var _crown_pid: int = -1          # who currently holds the crown
var _poop_pid: int = -1           # who currently holds last place


## Per-frame HUD refresh (called from main._process).
func update() -> void:
	var me: Player = main.players.get(main.local_id)
	if main.final_stage:
		main.timer_label.text = "Final Stage"
		main.timer_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	else:
		var t := int(main.elapsed)
		main.timer_label.text = "%02d:%02d" % [t / 60, t % 60]
		main.timer_label.add_theme_color_override("font_color", Color.WHITE)
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
	_update_rank_panel()
	# Pulse the async pick panel's header so banked upgrade credits draw the player's eye.
	if main.async_panel != null and main.async_panel.visible and main.async_panel_title != null:
		var t := Time.get_ticks_msec() / 1000.0
		main.async_panel_title.modulate.a = 0.6 + 0.4 * sin(t * TAU * 1.2)


## Live damage ranking panel: shows all players sorted by damage on the left side.
## In solo play hides itself; in multiplayer replaces the allies_label.
## Rows animate to their new Y position when the rank order changes.
func _update_rank_panel() -> void:
	if main.rank_panel == null:
		return
	var is_multi: bool = not (main as Main).is_solo()
	main.allies_label.visible = not is_multi
	main.rank_panel.visible = is_multi
	if not is_multi:
		# In solo: still show allies_label (empty) — no-op since there are no allies.
		return

	# Collect per-player damage from host _score or received net_rank_damages.
	var damages: Dictionary = {}
	if (main as Main).is_multiplayer_authority():
		for pid in main.peer_ids:
			damages[pid] = (main as Main)._score.get(pid, {}).get("damage", 0.0)
	else:
		for pid in main.peer_ids:
			damages[pid] = main.net_rank_damages.get(pid, 0.0)

	# Sort pids by damage descending.
	var sorted_pids: Array = main.peer_ids.duplicate()
	sorted_pids.sort_custom(func(a, b): return damages.get(a, 0.0) > damages.get(b, 0.0))

	# Ensure a label row exists for every current player.
	const ROW_H := 28
	for pid in main.peer_ids:
		if not _rank_rows.has(pid):
			var lbl := RichTextLabel.new()
			lbl.bbcode_enabled = true
			lbl.fit_content = true
			lbl.scroll_active = false
			lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lbl.custom_minimum_size = Vector2(380, ROW_H)
			lbl.add_theme_font_size_override("normal_font_size", 20)
			main.rank_panel.add_child(lbl)
			_rank_rows[pid] = lbl

	# Remove rows for players who left.
	for pid in _rank_rows.keys():
		if pid not in main.peer_ids:
			_rank_rows[pid].queue_free()
			_rank_rows.erase(pid)
			_rank_tweens.erase(pid)

	# Detect rank-order changes and animate row slides.
	var order_changed := sorted_pids != _rank_order
	var new_crown: int = sorted_pids[0] if not sorted_pids.is_empty() else -1
	var crown_changed := new_crown != _crown_pid and _crown_pid != -1
	_rank_order = sorted_pids.duplicate()
	var new_poop: int = sorted_pids[-1] if sorted_pids.size() > 1 else -1
	if new_crown != _crown_pid or new_poop != _poop_pid:
		for pid in main.peer_ids:
			var pp: Player = main.players.get(pid)
			if pp != null:
				pp.has_crown = (pid == new_crown)
				pp.has_poop = (pid == new_poop)
		_crown_pid = new_crown
		_poop_pid = new_poop

	for rank in sorted_pids.size():
		var pid: int = sorted_pids[rank]
		var lbl: RichTextLabel = _rank_rows.get(pid)
		if lbl == null:
			continue
		var target_y := float(rank * ROW_H)

		if order_changed and abs(lbl.position.y - target_y) > 1.0:
			if _rank_tweens.has(pid) and _rank_tweens[pid] != null and _rank_tweens[pid].is_valid():
				_rank_tweens[pid].kill()
			var tw := main.create_tween()
			tw.tween_property(lbl, "position:y", target_y, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_rank_tweens[pid] = tw
			# Flash new rank-1 row gold, then settle.
			if rank == 0 and crown_changed:
				lbl.modulate = Color(2.0, 1.8, 0.5)
				var tw2 := main.create_tween()
				tw2.tween_property(lbl, "modulate", Color.WHITE, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			lbl.position.y = target_y

		# Build the row text.
		var p: Player = main.players.get(pid)
		var col: Color = Player.COLORS[p.color_idx % Player.COLORS.size()] if p != null else Color.WHITE
		var glyph := Player.shape_glyph(p.shape_idx) if p != null else "●"
		var name_str: String = p.player_name if p != null else String(main.lobby_players.get(pid, {}).get("name", "?"))
		var ping := int(main.net_pings.get(pid, 0))
		var ping_s := " %dms" % ping if ping > 0 else ""
		var dmg_str := _fmt_dmg(damages.get(pid, 0.0))
		# HP + downed status per player — restored onto the leaderboard rows. Downed shows
		# revive progress (red); otherwise hearts/max (green). Same source the old allies
		# list read, so it stays live on clients too (ally hp/downed are synced).
		var status := ""
		if p != null:
			if p.downed:
				status = "[color=#ff5555]DOWN %d%%[/color]" % int(p.revive_progress * 100.0)
			else:
				status = "[color=#7ee08a]♥%d/%d[/color]" % [p.hp, p.max_hp]
		var away := "  [color=#6b7488](away)[/color]" if (p != null and p.disconnected) else ""

		var rank_badge: String
		if rank == 0:
			rank_badge = "[color=#ffd700]♛[/color] "
		elif rank == sorted_pids.size() - 1 and sorted_pids.size() > 1:
			rank_badge = "💩 "
		else:
			rank_badge = "[color=#6b7488]%d[/color]  " % (rank + 1)

		var bold_open := "[b]" if pid == main.local_id else ""
		var bold_close := "[/b]" if pid == main.local_id else ""
		lbl.text = "%s[color=#%s]%s %s%s%s[/color]  %s  [color=#ff9a8a]%s[/color][color=#39414f]%s[/color]%s" % [
			rank_badge, col.to_html(false), glyph,
			bold_open, name_str, bold_close,
			status, dmg_str, ping_s, away
		]


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
	elif w is WeaponFused:
		# Amalgam: list every fused weapon inside it with its own level + live output.
		lines.append("[color=#6b7488]─ fused weapons ─[/color]")
		lines.append_array(_fusion_parts_block(w))
	else:
		var desc := _fusion_desc(w)
		if desc != "":
			lines.append("[color=#7e8aa0]%s[/color]" % desc)
	return "[right]" + "\n".join(lines) + "[/right]"


## One row per component of an amalgam (WeaponFused): name + level + live DPS + total
## dealt, so hovering shows the stats of every weapon fused into the slot. dps/damage_dealt
## are tracked on every WeaponBase, so this works for base-weapon and signature-fusion parts.
func _fusion_parts_block(w) -> Array:
	var rows := []
	for c in w.get_children():
		if not (c is WeaponBase):
			continue
		var per_hit := ""
		if WeaponConfig.BASE.has(c.weapon_id):  # base-weapon part: show its effective per-hit DMG
			var b: Dictionary = WeaponConfig.BASE[c.weapon_id]
			var me: Player = main.players.get(main.local_id)
			var pwr: float = me.damage_mult if me != null else 1.0
			per_hit = "  [color=#ff9a8a]DMG %.1f[/color]" % (b.dmg * (1.0 + b.growth * (c.level - 1)) * pwr)
		rows.append("[color=#cdd6e6]%s[/color] [color=#9aa4b8]Lv%d[/color]%s  [color=#ff9a8a]%s/s[/color] [color=#7e8aa0]tot %s[/color]" \
			% [c.display_name, c.level, per_hit, _fmt_dmg(c.dps), _fmt_dmg(c.damage_dealt)])
	return rows


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


func show_final_stage_banner() -> void:
	if main.banner_label == null:
		return
	main.banner_label.text = "FINAL STAGE\nKILL ALL BOSSES TO WIN"
	main.banner_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	main.banner_label.add_theme_font_size_override("font_size", 58)
	main._banner_t = 5.0


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
