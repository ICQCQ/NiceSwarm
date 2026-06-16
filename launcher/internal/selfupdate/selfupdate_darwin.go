//go:build darwin

package selfupdate

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"niceswarm-launcher/internal/download"
	"niceswarm-launcher/internal/macapp"
	"niceswarm-launcher/internal/release"
)

// selfTarget resolves the running .app bundle from the inner Mach-O path
// (<App>.app/Contents/MacOS/<bin> → <App>.app) — the bundle is the unit swapped.
func selfTarget() (string, error) {
	exe, err := os.Executable()
	if err != nil {
		return "", err
	}
	app := filepath.Dir(filepath.Dir(filepath.Dir(exe))) // up: MacOS → Contents → .app
	if !strings.HasSuffix(app, ".app") {
		return "", fmt.Errorf("launcher is not running from a .app bundle (%s)", exe)
	}
	return app, nil
}

// stageNewLauncher downloads the launcher zip into a staging dir NEXT TO the running
// .app (same volume for the later rename), extracts it, verifies the inner Mach-O hash
// against the sidecar, and returns the path to the freshly extracted .app.
func stageNewLauncher(target, want string, prog download.Progress) (string, func(), error) {
	staging := filepath.Join(filepath.Dir(target), ".nslauncher-update")
	cleanup := func() { os.RemoveAll(staging) }
	os.RemoveAll(staging)
	if err := os.MkdirAll(staging, 0o755); err != nil {
		return "", cleanup, err
	}
	zipPath := filepath.Join(staging, "launcher.zip")
	if _, err := download.ToFile(release.LauncherDownloadURL(), zipPath, downloadTimeout, prog); err != nil {
		return "", cleanup, err
	}
	if err := macapp.Unzip(zipPath, staging); err != nil {
		return "", cleanup, err
	}
	app, err := macapp.FindApp(staging)
	if err != nil {
		return "", cleanup, err
	}
	inner, err := macapp.InnerBinary(app)
	if err != nil || inner == "" {
		return "", cleanup, fmt.Errorf("no inner binary in downloaded launcher .app")
	}
	if got := download.HashFile(inner); !strings.EqualFold(got, want) {
		return "", cleanup, fmt.Errorf("launcher hash mismatch: got %s, want %s", got, want)
	}
	return app, cleanup, nil
}

// postSwap clears Gatekeeper quarantine on the freshly installed bundle.
func postSwap(target string) { macapp.ClearQuarantine(target) }

// reExec launches the new bundle as a NEW instance. Plain `open` would just reactivate
// the still-running old instance (LaunchServices matches the bundle id); `-n` forces a
// fresh process from the new .app.
func reExec(target string) error {
	return exec.Command("open", "-n", target).Start()
}
