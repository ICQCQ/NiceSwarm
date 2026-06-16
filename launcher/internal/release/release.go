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
