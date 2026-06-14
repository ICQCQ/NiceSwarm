class_name BuildVersion
extends RefCounted
## Commit hash compiled into the build. build.ps1 overwrites COMMIT with
## `git describe --always --dirty` right before export (so it's baked into the .exe at
## build time, with no runtime git/file lookup) and restores this placeholder afterward.
## "dev" therefore means "running from source, not a packaged build".

const COMMIT := "dev"
