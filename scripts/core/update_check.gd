class_name UpdateCheck
extends Node
## Launch-time update notifier. Fetches the SHA256 sidecar of the latest published
## NiceSwarm.exe and compares it to the running executable; emits `update_available` when a
## different build is live. Only meaningful in an exported desktop build (the editor / headless
## / test runs have no game-exe to hash, so it no-ops there). Fully best-effort: every failure
## path is silent, so a launch never blocks or errors on the network.

signal update_available(remote_hash: String)

# Rolling "latest" release: stable URLs because the tag name is fixed. The shipped assets are
# per-platform AND per-arch — Windows x86_64 keeps its legacy bare names (NiceSwarm.exe /
# NiceSwarm-debug.exe) so already-installed builds keep matching; everything else gets an
# -arch suffix. The sidecar filename is computed at runtime from platform + arch + debug
# (see _sidecar_url) so a build only ever compares against its OWN asset.
const REL_BASE := "https://github.com/ICQCQ/NiceSwarm/releases/download/latest/"
const RELEASES_URL := "https://github.com/ICQCQ/NiceSwarm/releases/tag/latest"
const SKIP_CFG := "user://update_skip.cfg"
const TIMEOUT := 6.0

var _http: HTTPRequest


## Kick off the (async) check. Compares our exe against the rolling `latest` build (matching the
## user-facing "latest" release the game ships from); a versioned-tag build that differs would
## also be flagged, which Skip suppresses. Call once at startup.
func check() -> void:
	if _http != null:
		return  # a request is already in flight
	# Only an exported desktop build can hash its own exe; skip editor / headless / tests.
	if not OS.has_feature("template") or DisplayServer.get_name() == "headless":
		return
	_http = HTTPRequest.new()
	_http.timeout = TIMEOUT
	add_child(_http)
	_http.request_completed.connect(_on_completed)
	# Reached only inside an exported build (the has_feature("template") guard above), so
	# is_debug_build() / arch feature tags here reliably reflect the running export.
	if _http.request(_sidecar_url()) != OK:
		_http.queue_free()
		_http = null


## URL of the .sha256 sidecar for the running platform + arch + build flavour. Mirrors the CI
## asset naming: Windows x86_64 keeps legacy bare names; arm64 and macOS get an -arch suffix.
## macOS ships release-only (no debug build), so it ignores is_debug_build().
func _sidecar_url() -> String:
	var arch := "arm64" if OS.has_feature("arm64") else "x86_64"
	if OS.get_name() == "macOS":
		return REL_BASE + "NiceSwarm-%s.zip.sha256" % arch
	var asset := "NiceSwarm"
	if arch == "arm64":
		asset += "-arm64"  # x86_64 stays bare (legacy, pre-arm64 builds)
	if OS.is_debug_build():
		asset += "-debug"
	return REL_BASE + asset + ".exe.sha256"


func _on_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if is_instance_valid(_http):
		_http.queue_free()
		_http = null
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var remote := _parse_hash(body.get_string_from_ascii())
	var local := _self_hash()
	if remote == "" or local == "" or local == remote:
		return  # unparseable, un-hashable, or already up to date
	if _is_skipped(remote):
		return  # the user already dismissed this exact build
	update_available.emit(remote)


## Synchronous hash of our own exe. Runs once, only after the network round-trip succeeds, while
## we're on the menu — a brief one-time hitch (the exe is 50-150 MB) that is acceptable here.
func _self_hash() -> String:
	var path := OS.get_executable_path()
	if path == "" or not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_sha256(path)


## Pull the leading 64-hex-char token out of a "<hash>  NiceSwarm.exe" sidecar.
func _parse_hash(text: String) -> String:
	var parts := text.strip_edges().to_lower().split(" ", false)
	if parts.is_empty():
		return ""
	var first: String = parts[0]
	if first.length() == 64 and first.is_valid_hex_number(false):
		return first
	return ""


# --- "skip this version" persistence ------------------------------------------

func _is_skipped(remote_hash: String) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SKIP_CFG) != OK:
		return false
	return cfg.get_value("update", "skipped_hash", "") == remote_hash


func mark_skipped(remote_hash: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SKIP_CFG)  # ignore error — a fresh file is fine
	cfg.set_value("update", "skipped_hash", remote_hash)
	cfg.save(SKIP_CFG)
