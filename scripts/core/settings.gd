class_name GameSettings
extends RefCounted
## Client-local player preferences (audio / display / accessibility). Owned by Main
## as `main.settings`; deliberately NOT net-synced — every player keeps their own.
## Mirrors the profile save/load pattern (store_var dict at a user:// path).

const SAVE_PATH := "user://settings.cfg"

var volume := 1.0          # master bus level, 0.0–1.0
var muted := false         # mute toggle (independent of volume)
var fullscreen := false    # windowed (false) vs fullscreen
var screen_shake := true   # camera shake on hit/bomb (player.gd reads this live)
var net_interpolation := false  # smooth remote puppets via time-based snapshot interp (opt-in)


## Cycle the master volume in 10% steps, wrapping 100% → 0%. Pure so it's testable.
static func next_volume(v: float) -> float:
	var step := (int(round(v * 10.0)) + 1) % 11
	return step / 10.0


func load_from_disk(path := SAVE_PATH) -> void:
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var data = f.get_var()
	if typeof(data) != TYPE_DICTIONARY:
		return
	volume = clampf(float(data.get("volume", volume)), 0.0, 1.0)
	muted = bool(data.get("muted", muted))
	fullscreen = bool(data.get("fullscreen", fullscreen))
	screen_shake = bool(data.get("screen_shake", screen_shake))
	net_interpolation = bool(data.get("net_interpolation", net_interpolation))


func save(path := SAVE_PATH) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_var({
			"volume": volume, "muted": muted,
			"fullscreen": fullscreen, "screen_shake": screen_shake,
			"net_interpolation": net_interpolation,
		})


## Master is bus 0. linear_to_db(0.0) is -INF, so mute the bus instead of feeding
## that to set_bus_volume_db.
func apply_audio() -> void:
	if muted or volume <= 0.0:
		AudioServer.set_bus_mute(0, true)
	else:
		AudioServer.set_bus_mute(0, false)
		AudioServer.set_bus_volume_db(0, linear_to_db(volume))


func apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return  # no real window under headless/test runs
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)


func apply_all() -> void:
	apply_audio()
	apply_window()
