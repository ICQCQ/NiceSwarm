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
