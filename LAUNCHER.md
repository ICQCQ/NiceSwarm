# NiceSwarm Launcher (auto-updater)

A small, cross-platform launcher that keeps the game binary current and starts it.
It is the **primary thing a player downloads and keeps**; the ~100 MB game binary
itself is managed by the launcher in a per-user data directory.

> Built in **Go** (single self-contained binary, no runtime dependency, cross-compiles
> to every target from one CI runner). Lives in [`launcher/`](launcher/).

## Why a launcher (and not in-game self-update)

On Windows you **cannot overwrite a running `.exe`** — it is hard-locked. Every
auto-update design is just a different answer to *"who is running during the swap?"*.
The launcher runs while the game is **not** running, downloads into a directory it
fully controls, verifies, replaces, then launches the game. No locked-file dance, no
generated helper script. (`scripts/core/update_check.gd` keeps doing the in-game
*notice* — it hashes its own exe and shows a banner — but the launcher is what actually
performs the update.)

## Install model

The launcher downloads the game into a per-user data directory and runs it from there:

| OS | Game install location |
|----|----|
| Windows | `%LOCALAPPDATA%\NiceSwarm\NiceSwarm.exe` (+ `NiceSwarm-arm64.exe`, `NiceSwarm-debug.exe`) |
| macOS | `~/Library/Application Support/NiceSwarm/NiceSwarm.app` |

`%LOCALAPPDATA%` (Local), not Roaming — a 100 MB binary should not roam across machines.
Debug and release builds install **side-by-side** as distinct files, so toggling
`--debug` never clobbers the other or forces a re-download.

## Flow (every launch)

1. Resolve the target asset for this platform + arch + debug flag — mirrors
   `update_check.gd:_sidecar_url()` exactly.
2. `GET <latest>/<asset>.sha256` — the SHA256 sidecar CI publishes next to every binary.
3. Compare the remote hash to the locally-installed binary's hash (missing ⇒ "needs download").
4. If different/missing → download with a visible progress bar, **verify SHA256**, then
   atomically replace the installed binary.
5. Launch the installed game and exit.
6. **Offline-safe:** if the network or hash check fails but an install already exists,
   launch it anyway — a launch never blocks on the network (same philosophy as
   `update_check.gd`, where "every failure path is silent").

## Asset contract (reused, not reinvented)

The game's build workflow already publishes, for each binary, a
`"<lowercase-sha256>  <filename>"` sidecar to the rolling **`latest`** release tag.
The launcher reuses that contract verbatim:

| Platform | Game asset | Sidecar hashes |
|----------|-----------|----------------|
| Windows x86_64 | `NiceSwarm.exe` | the `.exe` |
| Windows x86_64 (debug) | `NiceSwarm-debug.exe` | the `.exe` |
| Windows arm64 | `NiceSwarm-arm64.exe` | the `.exe` |
| macOS (universal) | `NiceSwarm-macos.zip` | the **inner Mach-O** (`NiceSwarm.app/Contents/MacOS/NiceSwarm`), not the zip |

Download URL = sidecar URL minus `.sha256`. GitHub download URLs **302-redirect** to
`objects.githubusercontent.com`; the HTTP client follows redirects.

## `--debug` option

`--debug` selects the debug game build instead of release; `--release` forces release.
The choice is **persisted** to `launcher.json` in the data dir, so it sticks across runs
(no flag ⇒ use the stored value, default release).

- Debug installs as `NiceSwarm-debug.exe` and verifies against its own sidecar.
- ⚠️ **macOS has no debug build** (`update_check.gd` ignores `is_debug_build()` on mac;
  CI ships macOS release-only). On macOS `--debug` logs that debug is unavailable and
  falls back to release.
- Windows arm64 currently has no `-debug` CI asset either; `--debug` on arm64 falls back
  to x86_64 debug. Add an arm64-debug export in CI if that becomes wanted.

## Distribution: the launcher ships to its own `launcher` tag

The game ships to the rolling `latest` tag (every `publish` push). The launcher is
**decoupled** — the **Windows** build publishes to a separate **`launcher`** rolling
tag (the macOS build is artifact-only until validated on a real Mac — see Phasing):

```
…/releases/download/latest/NiceSwarm.exe            <- game (downloaded BY the launcher)
…/releases/download/launcher/NiceSwarm-Launcher.exe <- the launcher itself
```

The launcher build is **path-filtered** (`launcher/**`) + `workflow_dispatch`, so it
does **not** rebuild on every game commit. A Linux job cross-compiles the Windows
binaries; a separate macOS job builds the universal `.app`. (Pinned `launcher-v*` tag
releases are deferred — combining a `tags:` trigger with the `paths:` filter is a known
footgun, so it needs its own workflow; see Phasing.)

| Artifact | GOOS/GOARCH |
|----------|-------------|
| `NiceSwarm-Launcher.exe` | windows/amd64 |
| `NiceSwarm-Launcher-arm64.exe` | windows/arm64 |
| `NiceSwarm-Launcher-macos.zip` | darwin universal (amd64 + arm64) |

## macOS specifics

- Download `NiceSwarm-macos.zip`, extract, locate the `.app`, hash its **inner Mach-O**,
  compare to the sidecar (the zip is never what the sidecar hashes).
- Replace the `.app` under the data dir; **clear Gatekeeper quarantine** with
  `xattr -dr com.apple.quarantine <app>` (otherwise first launch is blocked — CLAUDE.md
  documents this manual step; the launcher automates it).
- Launch with `open <app>`.
- The launcher binary itself also needs quarantine cleared / ad-hoc signing to run; it is
  distributed inside its own minimal wrapper and ad-hoc signed in CI (matching the game's
  existing macOS signing). macOS support is implemented but **less tested than Windows**.

## Phasing

- **Phase 1 — Windows (core):** asset resolution, download + verify + atomic replace into
  `%LOCALAPPDATA%`, launch, progress UI, offline fallback, `--debug`. CI → `launcher` tag.
- **Phase 2 — macOS:** validate the zip handling, inner-Mach-O hash compare, `.app` replace,
  quarantine clear, and signed wrapper on a real Mac, then flip the CI macOS job from
  artifact-only to publishing the `launcher` tag. Address the no-terminal progress UX.
- **Phase 3 — polish:** pinned `launcher-v*` release workflow (separate file, no `paths:`
  filter); launcher **self-update** (it is now the locked file — rename-running-exe-to-`.old`,
  write new, re-exec, clean up next run); Windows arm64-debug asset.

## Build / run locally

```sh
cd launcher
go build -o NiceSwarm-Launcher.exe .   # or: go vet ./...
./NiceSwarm-Launcher.exe                # release; add --debug for the debug build
```
