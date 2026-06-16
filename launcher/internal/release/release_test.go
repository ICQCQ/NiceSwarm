package release

import (
	"runtime"
	"strings"
	"testing"
)

// On the dev/CI host (windows/amd64) Resolve must pick the bare release exe, and
// --debug must select the -debug asset. Guard so the assertions only run where they hold.
func TestResolveWindowsAmd64(t *testing.T) {
	if runtime.GOOS != "windows" || runtime.GOARCH != "amd64" {
		t.Skipf("host is %s/%s; this case asserts windows/amd64", runtime.GOOS, runtime.GOARCH)
	}
	rel, err := Resolve(false)
	if err != nil {
		t.Fatalf("Resolve(false): %v", err)
	}
	if rel.AssetFile != "NiceSwarm.exe" || rel.Debug {
		t.Errorf("release: got %+v, want NiceSwarm.exe (debug=false)", rel)
	}
	dbg, err := Resolve(true)
	if err != nil {
		t.Fatalf("Resolve(true): %v", err)
	}
	if dbg.AssetFile != "NiceSwarm-debug.exe" || !dbg.Debug {
		t.Errorf("debug: got %+v, want NiceSwarm-debug.exe (debug=true)", dbg)
	}
}

func TestSidecarURL(t *testing.T) {
	tgt := Target{AssetFile: "NiceSwarm.exe"}
	if got := tgt.SidecarURL(); !strings.HasSuffix(got, "/NiceSwarm.exe.sha256") {
		t.Errorf("SidecarURL = %q, want .../NiceSwarm.exe.sha256", got)
	}
	if got := tgt.DownloadURL(); !strings.HasSuffix(got, "/NiceSwarm.exe") {
		t.Errorf("DownloadURL = %q, want .../NiceSwarm.exe", got)
	}
}

// The launcher self-update check resolves its OWN asset on the `launcher` tag
// (Windows only for now; "" elsewhere).
func TestLauncherSelfResolve(t *testing.T) {
	switch runtime.GOOS {
	case "windows", "darwin": // platforms with a published launcher + self-update
	default:
		if got := LauncherAsset(); got != "" {
			t.Errorf("LauncherAsset on %s = %q, want \"\" (self-update unsupported)", runtime.GOOS, got)
		}
		if got := LauncherSidecarURL(); got != "" {
			t.Errorf("LauncherSidecarURL on %s = %q, want \"\"", runtime.GOOS, got)
		}
		return
	}
	want := "NiceSwarm-Launcher.exe"
	switch {
	case runtime.GOOS == "darwin":
		want = "NiceSwarm-Launcher-macos.zip"
	case runtime.GOARCH == "arm64":
		want = "NiceSwarm-Launcher-arm64.exe"
	}
	if got := LauncherAsset(); got != want {
		t.Errorf("LauncherAsset = %q, want %q", got, want)
	}
	got := LauncherSidecarURL()
	if !strings.Contains(got, "/releases/download/launcher/") || !strings.HasSuffix(got, "/"+want+".sha256") {
		t.Errorf("LauncherSidecarURL = %q, want .../launcher/%s.sha256", got, want)
	}
}
