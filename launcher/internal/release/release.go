// Package release resolves which published game asset to fetch for the current
// platform, mirroring scripts/core/update_check.gd:_sidecar_url() in the game repo.
package release

import (
	"fmt"
	"runtime"
)

const (
	// GameBase is the rolling "latest" release where CI publishes the game binaries.
	// Matches update_check.gd REL_BASE.
	GameBase = "https://github.com/ICQCQ/NiceSwarm/releases/download/latest/"
	// ReleasesPage is the human-facing page for the latest game release.
	ReleasesPage = "https://github.com/ICQCQ/NiceSwarm/releases/tag/latest"

	// LauncherBase is the rolling "launcher" release where CI publishes the launcher
	// binaries (decoupled from the game's `latest` tag).
	LauncherBase = "https://github.com/ICQCQ/NiceSwarm/releases/download/launcher/"
	// LauncherPage is the human-facing page for the launcher release.
	LauncherPage = "https://github.com/ICQCQ/NiceSwarm/releases/tag/launcher"
)

// Target describes the game asset to fetch/install for the running platform.
type Target struct {
	GOOS      string // "windows" | "darwin"
	AssetFile string // published filename, e.g. "NiceSwarm.exe" / "NiceSwarm-macos.zip"
	IsZip     bool   // macOS ships a zip that must be extracted before hashing
	Debug     bool   // resolved debug mode (may be downgraded from the request)
}

// Resolve picks the asset for runtime.GOOS/GOARCH and the requested debug mode.
// A debug build only exists for windows/amd64 (CI ships no -debug asset for arm64
// or macOS), so a debug request elsewhere is downgraded to that platform's release.
func Resolve(wantDebug bool) (Target, error) {
	switch runtime.GOOS {
	case "windows":
		debug := wantDebug && runtime.GOARCH == "amd64"
		name := "NiceSwarm"
		if runtime.GOARCH == "arm64" {
			name += "-arm64"
		}
		if debug {
			name += "-debug"
		}
		name += ".exe"
		return Target{GOOS: "windows", AssetFile: name, IsZip: false, Debug: debug}, nil
	case "darwin":
		// One universal, release-only zip — no arch split, no debug build.
		return Target{GOOS: "darwin", AssetFile: "NiceSwarm-macos.zip", IsZip: true, Debug: false}, nil
	default:
		return Target{}, fmt.Errorf("unsupported OS %q", runtime.GOOS)
	}
}

// DownloadURL is the asset URL.
func (t Target) DownloadURL() string { return GameBase + t.AssetFile }

// SidecarURL is the matching ".sha256" checksum file.
func (t Target) SidecarURL() string { return GameBase + t.AssetFile + ".sha256" }

// LauncherAsset returns the launcher's OWN published filename for this platform, used
// for the self-update check (does a newer launcher exist?). Returns "" where the
// self-check isn't supported yet — currently macOS, whose launcher ships as a .app
// inside a zip and is published artifact-only (see LAUNCHER.md Phase 2).
func LauncherAsset() string {
	if runtime.GOOS != "windows" {
		return ""
	}
	if runtime.GOARCH == "arm64" {
		return "NiceSwarm-Launcher-arm64.exe"
	}
	return "NiceSwarm-Launcher.exe"
}

// LauncherSidecarURL is the ".sha256" for this launcher's own asset, or "" if the
// self-check is unsupported on this platform.
func LauncherSidecarURL() string {
	a := LauncherAsset()
	if a == "" {
		return ""
	}
	return LauncherBase + a + ".sha256"
}
