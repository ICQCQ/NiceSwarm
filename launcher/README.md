# NiceSwarm Launcher

Small cross-platform auto-updater with a **Gio ([gioui.org](https://gioui.org/)) window**:
it keeps the game binary current and launches it. Design + rationale:
[`../LAUNCHER.md`](../LAUNCHER.md).

## Use

```sh
go build -o NiceSwarm-Launcher.exe .   # or just: go run .
./NiceSwarm-Launcher.exe                # opens the launcher window
```

The window auto-checks for a game update on open, shows a **progress bar** while
downloading, then enables **Play**. Controls:

- **Play** — launch the installed game (enabled once a build is ready).
- **Check for Updates** — re-run the check/download on demand.
- **Debug build** checkbox — switch between the release and debug game build
  (Windows x86_64 only); the choice is persisted to `launcher.json`.
- **Update Launcher** — appears when a newer launcher is published; downloads, verifies,
  swaps the running binary, and relaunches itself.

Flags still work and are persisted: `--debug` / `--release` set the initial build, and
`--headless` runs the original windowless flow (check → update → launch → exit) for
automation.

The game is installed under a per-user data dir (`%LOCALAPPDATA%\NiceSwarm` on Windows,
`~/Library/Application Support/NiceSwarm` on macOS), not next to the launcher.

## Layout

| Path | Role |
|------|------|
| `main.go` | entry: flags, data dir, `.old` cleanup, GUI vs `--headless` |
| `controller.go` | UI state + background workers (check/download, self-update, play) |
| `ui.go` | Gio layout + widget event handling (the window) |
| `headless.go` | legacy windowless flow behind `--headless` |
| `internal/release` | asset-name + URL resolution (mirrors `update_check.gd:_sidecar_url()`) |
| `internal/download` | HTTP fetch (follows GitHub redirects) + SHA256 verify + progress |
| `internal/install` | data dir, atomic replace (Win) / `.app` swap + quarantine clear (mac), launch |
| `internal/selfupdate` | rename-aside + verified swap + rollback for the launcher's own binary |
| `internal/config` | persists the `--debug` preference to `launcher.json` |
| `macos/Info.plist` | bundle manifest for the macOS `.app` wrapper (CI) |

## Test

```sh
go test ./internal/...                             # offline unit suite (skips the GUI package)
LAUNCHER_LIVE_TEST=1 go test ./internal/download/  # + live sidecar contract check
```

`go test ./internal/...` (not `./...`) is intentional: the Gio GUI package only builds
with a platform window backend (cgo + X11/Wayland on Linux), so it is excluded from the
headless suite. The GUI is covered by `go build` / `go vet` instead.

## Build / publish

CI (`.github/workflows/build-launcher.yml`) cross-compiles Windows x86_64/arm64 — Gio's
Windows backend is pure-Go, so this stays a CGO-free cross-build from Linux — and
publishes them to the **`launcher`** release tag (decoupled from the game's `latest`
tag). Windows binaries link the `windowsgui` subsystem (no stray console window). The
macOS universal `.app` requires cgo (AppKit/Metal) and is built + uploaded as a CI
artifact only until validated on a real Mac. Trigger: changes under `launcher/**` or
manual dispatch.
