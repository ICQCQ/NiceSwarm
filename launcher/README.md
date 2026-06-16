# NiceSwarm Launcher

Small cross-platform auto-updater: keeps the game binary current and launches it.
Design + rationale: [`../LAUNCHER.md`](../LAUNCHER.md).

## Use

```sh
go build -o NiceSwarm-Launcher.exe .   # or just: go run .
./NiceSwarm-Launcher.exe                # release build
./NiceSwarm-Launcher.exe --debug        # debug game build (Windows x86_64 only)
./NiceSwarm-Launcher.exe --release       # force release, clears a stored --debug
```

The game is installed under a per-user data dir (`%LOCALAPPDATA%\NiceSwarm` on Windows,
`~/Library/Application Support/NiceSwarm` on macOS), not next to the launcher.

## Layout

| Path | Role |
|------|------|
| `main.go` | flow: resolve target → check sidecar → download/verify/install → launch |
| `internal/release` | asset-name + URL resolution (mirrors `update_check.gd:_sidecar_url()`) |
| `internal/download` | HTTP fetch (follows GitHub redirects) + SHA256 verify + progress |
| `internal/install` | data dir, atomic replace (Win) / `.app` swap + quarantine clear (mac), launch |
| `internal/config` | persists the `--debug` preference to `launcher.json` |
| `macos/Info.plist` | bundle manifest for the macOS `.app` wrapper (CI) |

## Test

```sh
go test ./...                              # offline unit suite
LAUNCHER_LIVE_TEST=1 go test ./internal/download/   # + live sidecar contract check
```

## Build / publish

CI (`.github/workflows/build-launcher.yml`) cross-compiles Windows x86_64/arm64 and
publishes them to the **`launcher`** release tag (decoupled from the game's `latest`
tag). The macOS universal `.app` is built and uploaded as a CI artifact only, until it's
validated on a real Mac. Trigger: changes under `launcher/**` or manual dispatch.
