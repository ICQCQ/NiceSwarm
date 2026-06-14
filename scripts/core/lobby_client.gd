class_name LobbyClient
extends Node
## Client for the NiceSwarm Lobby Registry (server/lobby-registry). Lets the
## menu browse open online games and announce its own — with no IP:port. Talks
## plain HTTP/JSON; the host handle it carries is a Noray OID (Noray does the
## actual NAT traversal + relay). See NETWORKING.md §6.
##
## All calls are async — `await` them:
##   var res := await lobby.list_games("0.9.0")
##   if res.ok: for room in res.data.rooms: ...
## Every result is a Dictionary: { ok:bool, code:int, data:Variant, error:String }.

const TIMEOUT := 8.0

var base_url := ""  # defaults to GameConfig.lobby_url() in _ready


func _ready() -> void:
	if base_url == "":
		base_url = GameConfig.lobby_url()


## Browse joinable rooms for this build. data.rooms = [{room_id,name,host_oid,
## version,players,max_players,region}], data.other_versions = int.
func list_games(version: String) -> Dictionary:
	return await _request(HTTPClient.METHOD_GET, "/list?version=" + version.uri_encode(), "")


## Open a room. On ok, data = { room_id, token } — keep the token secret; it is
## required for heartbeat/withdraw.
func announce(room_name: String, version: String, host_oid: String, max_players: int) -> Dictionary:
	return await _request(HTTPClient.METHOD_POST, "/announce", JSON.stringify({
		"name": room_name,
		"version": version,
		"host_oid": host_oid,
		"max_players": max_players,
	}))


## Keep a room alive (~every 5 s) and update its player count / in-progress flag.
func heartbeat(room_id: String, token: String, players: int, in_progress: bool) -> Dictionary:
	return await _request(HTTPClient.METHOD_POST, "/heartbeat", JSON.stringify({
		"room_id": room_id,
		"token": token,
		"players": players,
		"in_progress": in_progress,
	}))


## Close a room (call on start-lock or leave). Idempotent.
func withdraw(room_id: String, token: String) -> Dictionary:
	return await _request(HTTPClient.METHOD_POST, "/withdraw", JSON.stringify({
		"room_id": room_id,
		"token": token,
	}))


# One request per call: spin up a short-lived HTTPRequest, await, free it. This
# keeps calls independent (no shared in-flight state) at the cost of a node per
# request — fine for the menu's low call rate.
func _request(method: int, path: String, body: String) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var err := http.request(base_url + path, headers, method, body)
	if err != OK:
		http.queue_free()
		return {"ok": false, "code": 0, "data": null, "error": "request error %d" % err}

	var res: Array = await http.request_completed  # [result, code, headers, body]
	http.queue_free()

	var result: int = res[0]
	var code: int = res[1]
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "code": code, "data": null, "error": "http result %d" % result}

	var text: String = (res[3] as PackedByteArray).get_string_from_utf8()
	var data: Variant = JSON.parse_string(text) if text != "" else null
	var ok := code >= 200 and code < 300
	var msg := "" if ok else (str(data.get("error", "")) if data is Dictionary else "http %d" % code)
	return {"ok": ok, "code": code, "data": data, "error": msg}
