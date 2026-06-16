// Package install manages the on-disk game install: locating the per-user data dir,
// checking whether the installed binary matches a wanted hash, applying a freshly
// downloaded asset (atomic replace on Windows, .app swap + quarantine clear on macOS),
// and launching the game.
package install

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"time"

	"niceswarm-launcher/internal/download"
	"niceswarm-launcher/internal/macapp"
	"niceswarm-launcher/internal/release"
)

// downloadTimeout is generous — the game binary is ~100 MB and the whole transfer
// (including the body read) is covered by the http.Client timeout.
const downloadTimeout = 30 * time.Minute

// DataDir returns the per-user directory where the managed game install lives.
func DataDir() (string, error) {
	switch runtime.GOOS {
	case "windows":
		base := os.Getenv("LOCALAPPDATA")
		if base == "" {
			up := os.Getenv("USERPROFILE")
			if up == "" {
				return "", fmt.Errorf("LOCALAPPDATA and USERPROFILE both unset")
			}
			base = filepath.Join(up, "AppData", "Local")
		}
		return filepath.Join(base, "NiceSwarm"), nil
	case "darwin":
		home, err := os.UserHomeDir()
		if err != nil {
			return "", err
		}
		return filepath.Join(home, "Library", "Application Support", "NiceSwarm"), nil
	default:
		return "", fmt.Errorf("unsupported OS %q", runtime.GOOS)
	}
}

// LaunchTarget is the path handed to Launch: the .exe on Windows, the .app on macOS.
func LaunchTarget(dataDir string, t release.Target) string {
	if t.GOOS == "darwin" {
		return filepath.Join(dataDir, "NiceSwarm.app")
	}
	return filepath.Join(dataDir, t.AssetFile)
}

// installedExecutable returns the path whose SHA256 should equal the sidecar hash:
// the .exe on Windows, the inner Mach-O of the .app on macOS ("" if not installed).
func installedExecutable(dataDir string, t release.Target) (string, error) {
	if t.GOOS == "darwin" {
		return macapp.InnerBinary(filepath.Join(dataDir, "NiceSwarm.app"))
	}
	return filepath.Join(dataDir, t.AssetFile), nil
}

// Exists reports whether a runnable install is already present.
func Exists(dataDir string, t release.Target) bool {
	exe, err := installedExecutable(dataDir, t)
	if err != nil || exe == "" {
		return false
	}
	_, err = os.Stat(exe)
	return err == nil
}

// IsCurrent reports whether the installed game already matches wantHash.
func IsCurrent(dataDir string, t release.Target, wantHash string) bool {
	exe, err := installedExecutable(dataDir, t)
	if err != nil || exe == "" {
		return false
	}
	if _, err := os.Stat(exe); err != nil {
		return false
	}
	return strings.EqualFold(download.HashFile(exe), wantHash)
}

// Apply downloads the target asset and installs it, verifying wantHash before any
// swap. The game must not be running (the launcher launches it afterwards), so the
// destination is never locked.
func Apply(dataDir string, t release.Target, wantHash string, prog download.Progress) error {
	if err := os.MkdirAll(dataDir, 0o755); err != nil {
		return err
	}
	if t.GOOS == "darwin" {
		return applyMac(dataDir, t, wantHash, prog)
	}
	return applyWindows(dataDir, t, wantHash, prog)
}

func applyWindows(dataDir string, t release.Target, wantHash string, prog download.Progress) error {
	dest := filepath.Join(dataDir, t.AssetFile)
	tmp := dest + ".tmp"
	got, err := download.ToFile(t.DownloadURL(), tmp, downloadTimeout, prog)
	if err != nil {
		return err
	}
	if !strings.EqualFold(got, wantHash) {
		os.Remove(tmp)
		return fmt.Errorf("hash mismatch: got %s, want %s", got, wantHash)
	}
	if err := os.Rename(tmp, dest); err != nil { // Go's os.Rename replaces existing on Windows
		os.Remove(tmp)
		return err
	}
	return nil
}

func applyMac(dataDir string, t release.Target, wantHash string, prog download.Progress) error {
	zipTmp := filepath.Join(dataDir, "NiceSwarm-macos.zip.tmp")
	// The sidecar hashes the inner Mach-O, NOT the zip, so don't verify the zip here.
	if _, err := download.ToFile(t.DownloadURL(), zipTmp, downloadTimeout, prog); err != nil {
		return err
	}
	defer os.Remove(zipTmp)

	staging := filepath.Join(dataDir, "_staging")
	os.RemoveAll(staging)
	defer os.RemoveAll(staging)
	if err := macapp.Unzip(zipTmp, staging); err != nil {
		return err
	}
	stagedApp, err := macapp.FindApp(staging)
	if err != nil {
		return err
	}
	inner, err := macapp.InnerBinary(stagedApp)
	if err != nil || inner == "" {
		return fmt.Errorf("no inner binary in downloaded .app")
	}
	if got := download.HashFile(inner); !strings.EqualFold(got, wantHash) {
		return fmt.Errorf("hash mismatch: got %s, want %s", got, wantHash)
	}

	finalApp := filepath.Join(dataDir, "NiceSwarm.app")
	os.RemoveAll(finalApp)
	if err := os.Rename(stagedApp, finalApp); err != nil {
		return err
	}
	macapp.ClearQuarantine(finalApp) // best-effort: unblock the first launch
	return nil
}

// Launch starts the installed game detached and returns immediately.
func Launch(path string) error {
	if runtime.GOOS == "darwin" {
		return exec.Command("open", path).Start()
	}
	return exec.Command(path).Start()
}
