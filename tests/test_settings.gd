extends RefCounted
## GameSettings: pure volume-step cycling + a real save/load round-trip through a
## temp user:// file (never touches the player's actual settings.cfg).

const TMP := "user://settings_test.cfg"


func run(t) -> void:
	t.suite("settings")

	# next_volume: 10% steps, wrapping 100% -> 0%
	t.approx(GameSettings.next_volume(0.0), 0.1, 0.001, "vol 0 -> 0.1")
	t.approx(GameSettings.next_volume(0.5), 0.6, 0.001, "vol 0.5 -> 0.6")
	t.approx(GameSettings.next_volume(0.9), 1.0, 0.001, "vol 0.9 -> 1.0")
	t.approx(GameSettings.next_volume(1.0), 0.0, 0.001, "vol 1.0 wraps to 0")

	# save -> fresh load round-trips every field
	var a := GameSettings.new()
	a.volume = 0.3
	a.muted = true
	a.fullscreen = true
	a.screen_shake = false
	a.save(TMP)
	var b := GameSettings.new()
	b.load_from_disk(TMP)
	t.approx(b.volume, 0.3, 0.001, "volume persists")
	t.eq(b.muted, true, "muted persists")
	t.eq(b.fullscreen, true, "fullscreen persists")
	t.eq(b.screen_shake, false, "screen_shake persists")

	# load clamps an out-of-range volume into 0..1
	a.volume = 5.0
	a.save(TMP)
	var c := GameSettings.new()
	c.load_from_disk(TMP)
	t.approx(c.volume, 1.0, 0.001, "volume clamps to 1.0 on load")

	# missing file leaves current values untouched
	var d := DirAccess.open("user://")
	if d != null:
		d.remove("settings_test.cfg")
	var e := GameSettings.new()
	e.volume = 0.42
	e.load_from_disk(TMP)
	t.approx(e.volume, 0.42, 0.001, "missing file keeps current value")
