extends RefCounted
## Validates Main.STAT_INFO — the stat-upgrade metadata that drives BOTH the debug
## panel's stat grid (reads .label) and the on-screen stat-level icons (reads .icon
## / .color). Each entry must be a well-formed dict so neither consumer breaks.

func run(t) -> void:
	t.suite("stats")
	var info: Dictionary = Main.STAT_INFO
	t.gt(info.size(), 0, "STAT_INFO non-empty")
	for sid in info:
		t.ok(sid is String and (sid as String).begins_with("st_"),
			"id %s looks like a stat id" % str(sid))
		var e = info[sid]
		t.ok(e is Dictionary, "%s entry is a dict" % str(sid))
		if e is Dictionary:
			t.ok(e.get("label", "") is String and e.get("label", "") != "",
				"%s has a label" % str(sid))
			t.ok(e.get("icon", "") is String and e.get("icon", "") != "",
				"%s has an icon glyph" % str(sid))
			t.ok(e.get("color", null) is Color, "%s has a color" % str(sid))
