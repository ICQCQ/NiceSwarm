# NiceSwarm Launcher (auto-updater)

A small, cross-platform launcher that keeps the game binary current and starts it.
It is the **primary thing a player downloads and keeps**; the ~100 MB game binary
itself is managed by the launcher in a per-user data directory.

> Built in **Go** with a **Gio ([gioui.org](https://gioui.org/)) window** — a single
> self-contained binary, no runtime dependency. The Windows backend is pure-Go, so it
> still cross-compiles CGO-free from one Linux CI runner; macOS needs cgo (AppKit/Metal)
> and builds on a Mac runner. Lives in [`launcher/`](launcher/).
>
> The window auto-checks on open, shows a **progress bar** during downloads, then enables
> **Play**. It also exposes a manual **Check for Updates** button, a **Debug build**
> toggle, and — when a newer launcher is published — an **Update Launcher** button that
> performs a real self-replace. A `--headless` flag keeps the original windowless flow.

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

The window **auto-checks on open** (and re-checks on demand via **Check for Updates**):

1. Resolve the target asset for this platform + arch + debug toggle — mirrors
   `update_check.gd:_sidecar_url()` exactly.
2. `GET <latest>/<asset>.sha256` — the SHA256 sidecar CI publishes next to every binary.
3. Compare the remote hash to the locally-installed binary's hash (missing ⇒ "needs download").
4. If different/missing → download (the **progress bar** fills), **verify SHA256**, then
   atomically replace the installed binary.
5. When a runnable build is present, **Play** is enabled; clicking it launches the game and
   exits the launcher. (The window stays open until the player clicks Play — it no longer
   auto-launches, so Check / Debug / Update Launcher stay reachable.)
6. **Offline-safe:** if the network or hash check fails but an install already exists, the
   status says so and Play is still enabled — nothing blocks on the network (same
   philosophy as `update_check.gd`, where "every failure path is silent").

Background work runs in goroutines; a single mutex-guarded "busy" slot ensures only one
operation (check / download / self-update / launch) runs at a time, and each state change
calls `window.Invalidate()` so the next frame reflects it. `--headless` runs the original
windowless check → update → launch → exit instead.

## Launcher self-update

On open the launcher hashes its own executable (`os.Executable()`) and compares it to a
`.sha256` sidecar published for the launcher binary on the `launcher` tag (CI emits these
alongside the binaries). On a mismatch the window surfaces an **Update Launcher** button.

Clicking it performs a real self-replace (`internal/selfupdate`). Neither OS lets you
clobber a running image in place, but both let you move it aside. The unit swapped (the
"target") is the **`.exe` on Windows** and the **whole `.app` bundle on macOS**:

1. Fetch the launcher sidecar hash, then stage the new launcher **next to the target**
   (same volume, so the later rename is atomic): Windows downloads to `<exe>.new`; macOS
   downloads the zip into a staging dir beside the `.app`, extracts it, and locates the
   new `.app`.
2. **Verify SHA256 before any swap** — Windows over the downloaded `.exe`, macOS over the
   extracted **inner Mach-O** (matching the sidecar). A mismatch aborts, launcher untouched.
3. `Replace`: move `target` → `target.old` (frees the path), then move the new copy into
   place. **If that move fails, `target.old` is renamed back** — a botched update never
   leaves the user without a working launcher.
4. Platform post-swap: macOS clears Gatekeeper quarantine on the new bundle.
5. Re-exec the new copy — Windows runs the new `.exe` (same args); macOS uses `open -n`
   (a plain `open` would just reactivate the still-running old instance) — then exit.
6. The next startup runs `CleanupSelf` to delete the parked `target.old`
   (`os.RemoveAll`, since on macOS the backup is a directory).

Best-effort throughout: any failure (offline, 404, unhashable, read-only directory) is
reported in the status line and leaves the launcher intact. The shared move/rollback +
verify-then-swap orchestration lives in `selfupdate.go`; the per-OS target resolution,
download staging, and re-exec live in the build-tagged `selfupdate_windows.go` /
`selfupdate_darwin.go` (a `selfupdate_other.go` stub keeps non-launcher platforms, e.g.
the Linux CI runner, compiling). The in-game `scripts/core/update_check.gd` still shows
its own banner notice; the launcher is what performs both the game and launcher updates.

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

## Debug build option

The **Debug build** checkbox in the window switches between the release and debug game
build; toggling it persists the choice and immediately re-checks against the other asset.
The `--debug` / `--release` flags do the same from the command line and set the initial
state. The choice is **persisted** to `launcher.json` in the data dir, so it sticks across
runs (no flag ⇒ use the stored value, default release).

- Debug installs as `NiceSwarm-debug.exe` and verifies against its own sidecar.
- ⚠️ **macOS has no debug build** (`update_check.gd` ignores `is_debug_build()` on mac;
  CI ships macOS release-only). On macOS `--debug` logs that debug is unavailable and
  falls back to release.
- Windows arm64 currently has no `-debug` CI asset either; `--debug` on arm64 falls back
  to x86_64 debug. Add an arm64-debug export in CI if that becomes wanted.

## Distribution: the launcher ships to its own `launcher` tag

The game ships to the rolling `latest` tag (every `publish` push). The launcher is
**decoupled** — both the Windows and the macOS builds publish to a separate **`launcher`**
rolling tag (the macOS binary is CI-compiled but runtime-unverified on a real Mac — see
Phasing):

```
…/releases/download/latest/NiceSwarm.exe            <- game (downloaded BY the launcher)
…/releases/download/launcher/NiceSwarm-Launcher.exe <- the launcher itself
```

The launcher build is **path-filtered** (`launcher/**`) + `workflow_dispatch`, so it
does **not** rebuild on every game commit. A Linux job cross-compiles the Windows
binaries; a separate macOS job (`needs: launcher-windows`, so the two don't race the
shared `launcher` release) builds + publishes the universal `.app`. (Pinned `launcher-v*`
tag releases are deferred — combining a `tags:` trigger with the `paths:` filter is a
known footgun, so it needs its own workflow; see Phasing.)

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
  existing macOS signing).
- **Launcher self-update on macOS** swaps the whole running `.app` bundle (it isn't
  hard-locked like a Windows `.exe`): stage the new `.app` beside the old one, verify the
  inner Mach-O hash, rename-swap with rollback, clear quarantine, and re-exec with
  `open -n`. The self-check hashes `os.Executable()` (the inner Mach-O), which equals the
  sidecar CI publishes **after** ad-hoc signing.
- ⚠️ macOS support is **CI-compiled on a real Mac VM but not yet runtime-verified** on
  physical hardware. The rename-with-rollback swap is the safety net that makes
  ship-then-validate acceptable; treat the macOS launcher as beta until confirmed on a Mac.

## Phasing

- **Phase 1 — Windows (core):** ✅ asset resolution, download + verify + atomic replace into
  `%LOCALAPPDATA%`, launch, offline fallback, `--debug`, **Gio window with a progress bar,
  Check-for-Updates button, and Debug toggle**. CI → `launcher` tag.
- **Phase 2 — macOS:** ✅ implemented (CI-compiled on a real Mac VM): Gio window, game
  install via zip/inner-Mach-O hash/`.app` swap/quarantine clear, the `.app`-swap launcher
  self-replace, ad-hoc-signed wrapper, sidecar hashed after signing, and **published to the
  `launcher` tag**. The Gio window also retired the old no-terminal-progress UX. Remaining:
  runtime validation on physical Apple hardware (the build is unverified there).
- **Phase 3 — polish:** ✅ launcher **self-replace** ships on both Windows and macOS
  (move-aside → verify → swap → re-exec → clean up next run — see `internal/selfupdate`).
  Remaining: pinned `launcher-v*` release workflow (separate file, no `paths:` filter); a
  Windows arm64-debug asset.

## Build / run locally

```sh
cd launcher
go build -o NiceSwarm-Launcher.exe .   # or: go vet ./... ; go test ./internal/...
./NiceSwarm-Launcher.exe                # opens the window; --debug preselects the debug build
./NiceSwarm-Launcher.exe --headless     # legacy windowless flow (automation)
```
