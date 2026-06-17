class_name BuildVersion
extends RefCounted
## Build identity compiled into the exe at build time. build.ps1 and the CI workflow
## overwrite BRANCH/COMMIT/COUNT right before export (BRANCH = git branch/tag, COMMIT =
## `git rev-parse --short HEAD` plus a `-dirty` suffix for a modified local build.ps1
## build, COUNT = `git rev-list --count HEAD`), so the version is baked in with no runtime
## git/file lookup; build.ps1 then restores these placeholders afterward. The "dev"
## defaults therefore mean "running from source, not a packaged build".
## Kept ASCII-only: build.ps1/CI rewrite this file with -Encoding ascii.

const BRANCH := "dev"   # git branch (or tag) the build came from, e.g. "publish"
const COMMIT := "dev"   # short sha; "-dirty" suffix marks a modified local build
const COUNT := "0"      # commit number on the branch (git rev-list --count HEAD)


## Headline build version: "Publish v. 220" (branch + commit count). "dev build" from source.
static func label() -> String:
	if COMMIT == "dev":
		return "dev build"
	var name := BRANCH
	if name.is_empty() or name == "HEAD":
		name = "build"
	return "%s v. %s" % [_title_first(name), COUNT]


## Headline + short sha (+ "*" dirty marker) for in-game traceability: "Publish v. 220 (9da5762)".
static func full_label() -> String:
	if COMMIT == "dev":
		return "dev"
	var sha := COMMIT
	var dirty := ""
	if sha.ends_with("-dirty"):
		sha = sha.trim_suffix("-dirty")
		dirty = " *"
	return "%s (%s%s)" % [label(), sha, dirty]


## Uppercase only the first character (NOT String.capitalize(), which also splits on
## "_"/spaces) so this matches the launcher's Go/CI title-casing exactly.
static func _title_first(s: String) -> String:
	if s.is_empty():
		return s
	return s.substr(0, 1).to_upper() + s.substr(1)
