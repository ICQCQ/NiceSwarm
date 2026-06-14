extends SceneTree
## Headless integration test for LobbyClient <-> Lobby Registry.
## Requires a running registry (server/lobby-registry). Point at it with
## NICESWARM_LOBBY_URL (defaults to http://127.0.0.1:8088).
##
##   node server/lobby-registry/src/server.js &      # start registry
##   godot --headless --path . -s res://tests/lobby_client_test.gd
##
## Prints "[lobby-test] PASS" / "[lobby-test] FAIL ..." and exits non-zero on fail.

var _fail := 0


func _initialize() -> void:
	_run()


func _check(cond: bool, label: String) -> void:
	if cond:
		print("[lobby-test]  ok  - ", label)
	else:
		_fail += 1
		printerr("[lobby-test] FAIL - ", label)


func _run() -> void:
	var lobby := LobbyClient.new()
	lobby.base_url = GameConfig.lobby_url()
	get_root().add_child(lobby)
	await self.process_frame

	print("[lobby-test] registry = ", lobby.base_url)
	var version := "0.9.0"
	var oid := "oid_test_%d" % (randi() % 1_000_000)

	# 1) announce
	var a: Dictionary = await lobby.announce("Headless Test", version, oid, 4)
	_check(a.ok, "announce ok (code %d %s)" % [a.code, a.error])
	if not a.ok:
		return _finish()
	var room_id: String = a.data.room_id
	var token: String = a.data.token
	_check(room_id != "" and token != "", "got room_id + secret token")

	# 2) list shows our room (and never leaks the token)
	var l1: Dictionary = await lobby.list_games(version)
	_check(l1.ok, "list ok")
	var found := _has_room(l1, room_id, oid)
	_check(found, "our room appears in same-version list")
	_check(not _list_leaks_token(l1), "list never exposes a token")

	# 3) other-version client does not see it
	var l2: Dictionary = await lobby.list_games("0.0.1")
	_check(not _has_room(l2, room_id, oid), "room hidden from other-version client")
	_check(int(l2.data.other_versions) >= 1, "other_versions counts our room")

	# 4) heartbeat + withdraw
	var hb: Dictionary = await lobby.heartbeat(room_id, token, 2, false)
	_check(hb.ok, "heartbeat ok")
	var bad: Dictionary = await lobby.heartbeat(room_id, "wrong-token", 2, false)
	_check(not bad.ok, "heartbeat with bad token rejected")
	var w: Dictionary = await lobby.withdraw(room_id, token)
	_check(w.ok, "withdraw ok")

	# 5) gone after withdraw
	var l3: Dictionary = await lobby.list_games(version)
	_check(not _has_room(l3, room_id, oid), "room gone after withdraw")

	_finish()


func _has_room(res: Dictionary, room_id: String, oid: String) -> bool:
	if not res.ok or not (res.data is Dictionary):
		return false
	for room in res.data.get("rooms", []):
		if room.get("room_id", "") == room_id or room.get("host_oid", "") == oid:
			return true
	return false


func _list_leaks_token(res: Dictionary) -> bool:
	if not res.ok or not (res.data is Dictionary):
		return false
	for room in res.data.get("rooms", []):
		if room.has("token") or room.has("ip"):
			return true
	return false


func _finish() -> void:
	if _fail == 0:
		print("[lobby-test] PASS")
		quit(0)
	else:
		printerr("[lobby-test] FAIL (%d checks)" % _fail)
		quit(1)
