package main

import "unicode"

// Build identity injected at build time via -ldflags "-X main.verBranch=... -X
// main.verCount=...". The two-var split (rather than one pre-formatted string) sidesteps
// go tool link's space-splitting of -ldflags values. The "dev"/"0" defaults mean a plain
// local `go build` (running from source, not a CI-published launcher).
var (
	verBranch = "dev"
	verCount  = "0"
)

// launcherVersion is the headline launcher build version, mirroring the game's
// BuildVersion.label(): "Publish v. 220" (branch + commit count), or "dev build" from source.
func launcherVersion() string {
	if verBranch == "dev" {
		return "dev build"
	}
	name := verBranch
	if name == "" || name == "HEAD" {
		name = "build"
	}
	return titleFirst(name) + " v. " + verCount
}

// titleFirst uppercases only the first character (NOT a per-word title-case), matching the
// game's BuildVersion._title_first so the two never diverge on a multi-word branch name.
func titleFirst(s string) string {
	if s == "" {
		return s
	}
	r := []rune(s)
	r[0] = unicode.ToUpper(r[0])
	return string(r)
}
