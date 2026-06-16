//go:build windows

package selfupdate

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	"niceswarm-launcher/internal/download"
	"niceswarm-launcher/internal/release"
)

// selfTarget is the running .exe — the unit swapped on Windows.
func selfTarget() (string, error) { return os.Executable() }

// stageNewLauncher downloads the new exe next to the running one (same volume for the
// later rename), verifies its SHA256, and returns the staged path.
func stageNewLauncher(target, want string, prog download.Progress) (string, func(), error) {
	tmp := target + ".new"
	cleanup := func() { os.Remove(tmp) }
	got, err := download.ToFile(release.LauncherDownloadURL(), tmp, downloadTimeout, prog)
	if err != nil {
		return "", cleanup, err
	}
	if !strings.EqualFold(got, want) {
		return "", cleanup, fmt.Errorf("launcher hash mismatch: got %s, want %s", got, want)
	}
	return tmp, cleanup, nil
}

// postSwap has nothing extra to do on Windows.
func postSwap(string) {}

// reExec launches the freshly written launcher with the same args and std streams.
func reExec(target string) error {
	cmd := exec.Command(target, os.Args[1:]...)
	cmd.Stdout, cmd.Stderr, cmd.Stdin = os.Stdout, os.Stderr, os.Stdin
	return cmd.Start()
}
