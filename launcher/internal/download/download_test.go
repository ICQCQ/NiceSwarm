package download

import (
	"os"
	"testing"
	"time"
)

func TestParseSidecar(t *testing.T) {
	good := "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
	cases := []struct {
		name, in, want string
		wantErr        bool
	}{
		{"standard two-space", good + "  NiceSwarm.exe", good, false},
		{"uppercased", "ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789  x", "abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789", false},
		{"trailing newline", good + "  NiceSwarm.exe\n", good, false},
		{"empty", "", "", true},
		{"too short", "deadbeef  x", "", true},
		{"not hex", "zz23456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef00  x", "", true},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			got, err := parseSidecar(c.in)
			if (err != nil) != c.wantErr {
				t.Fatalf("err = %v, wantErr = %v", err, c.wantErr)
			}
			if !c.wantErr && got != c.want {
				t.Errorf("got %q, want %q", got, c.want)
			}
		})
	}
}

// Live check against the real published sidecar — proves the URL is right and the
// GitHub 302 redirect is followed. Opt-in (set LAUNCHER_LIVE_TEST=1) so the offline
// unit suite stays green.
func TestSidecarHashLive(t *testing.T) {
	if os.Getenv("LAUNCHER_LIVE_TEST") == "" {
		t.Skip("set LAUNCHER_LIVE_TEST=1 to run the live network check")
	}
	const url = "https://github.com/ICQCQ/NiceSwarm/releases/download/latest/NiceSwarm.exe.sha256"
	h, err := SidecarHash(url, 15*time.Second)
	if err != nil {
		t.Fatalf("SidecarHash: %v", err)
	}
	if len(h) != 64 {
		t.Errorf("hash %q has length %d, want 64", h, len(h))
	}
	t.Logf("live sidecar hash: %s", h)
}
