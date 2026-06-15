class_name BuildVersion
extends RefCounted
## Commit id compiled into the build. build.ps1 and the CI workflow overwrite COMMIT with
## the short commit hash right before export -- `git rev-parse --short HEAD`, plus a `-dirty`
## suffix for a local build.ps1 build made from a modified (tracked) working tree -- so it is
## baked into the .exe at build time with no runtime git/file lookup; build.ps1 then restores
## this placeholder afterward. "dev" therefore means "running from source, not a packaged build".
## Kept ASCII-only: build.ps1/CI rewrite this file with -Encoding ascii.

const COMMIT := "dev"

## Build tag for display: the bare short id, or "<id> - DIRTY" for a dirty local build.
static func commit_label() -> String:
	if COMMIT.ends_with("-dirty"):
		return "%s - DIRTY" % COMMIT.trim_suffix("-dirty")
	return COMMIT
