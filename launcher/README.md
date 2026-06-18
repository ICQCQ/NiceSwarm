# NiceSwarm Launcher

Small cross-platform auto-updater with a **Gio ([gioui.org](https://gioui.org/)) window**:
it keeps the game binary current and launches it. Design + rationale:
[`../LAUNCHER.md`](../LAUNCHER.md).

## Use

```sh
go build -o NiceSwarm-Launcher.exe .   # or just: go run .
./NiceSwarm-Launcher.exe                # opens the launcher window
```

The window shows the **launcher's own build version** ("Publish v. 220", branch + commit
count, injected via `-ldflags`; see `version.go`) under the title, and — once the update
check has run — the **published game build version** it will install (fetched from the
`VERSION.txt` asset CI publishes next to the binaries). It auto-checks for a game update on
open, shows a **progress bar** while downloading, then enables **Play**. Controls:

- **Play** — launch the installed game (enabled once a build is ready).
- **Check for Updates** — re-run the check/download on demand.
- **Force Update** — re-download and reinstall the latest build even when the installed
  copy already matches (skips the "already up to date" short-circuit). Useful to repair a
  corrupt install or re-pull after a force-push to `latest`.
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
| `internal/macapp` | shared macOS bundle helpers: unzip, find `.app`, inner Mach-O, quarantine |
| `internal/selfupdate` | move-aside + verified swap + rollback + re-exec for the launcher itself (`_windows`/`_darwin`/`_other` per-OS files) |
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
macOS universal `.app` requires cgo (AppKit/Metal), is built + ad-hoc-signed on the
`macos-latest` runner, and is **also published** to the `launcher` tag (its sidecar hashes
the inner Mach-O *after* signing) — CI-compiled but runtime-unverified on physical Apple
hardware, so treat it as beta. Trigger: changes under `launcher/**` or manual dispatch.

## Windows code signing (antivirus / SmartScreen)

The build embeds a **PE version resource** (`versioninfo.json` → `goversioninfo` →
`.syso`) so the bare Go GUI exe presents as a normal app — this lowers the AV
false-positive rate but is not a guaranteed fix.

The build **optionally code-signs** the Windows exes when two repo Secrets are set
(Settings → Secrets and variables → Actions). Absent them, signing is skipped and the
build still passes:

| Secret | Value |
|--------|-------|
| `WINDOWS_CERT_BASE64` | the code-signing `.pfx`, base64-encoded |
| `WINDOWS_CERT_PASSWORD` | the `.pfx` export password |

Encode the cert: `base64 -w0 cert.pfx` (Linux) / `[Convert]::ToBase64String([IO.File]::ReadAllBytes("cert.pfx"))` (PowerShell) → paste as `WINDOWS_CERT_BASE64`.
CI signs with `osslsigncode` + an RFC3161 timestamp (so signatures stay valid after the
cert expires).

⚠️ **Only a CA-issued OV/EV certificate** actually clears Defender/SmartScreen. A
**self-signed** cert will sign here but Windows doesn't trust it, so it won't help end
users (and can read as malware faking a publisher). For a fast free win on a specific
flag, also submit the exe to Microsoft's false-positive portal
(`microsoft.com/wdsi/filesubmission`).
