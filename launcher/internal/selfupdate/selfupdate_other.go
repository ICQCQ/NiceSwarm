//go:build !windows && !darwin

package selfupdate

import (
	"fmt"

	"niceswarm-launcher/internal/download"
)

// These stubs keep the package compiling on platforms with no published launcher (e.g.
// the Linux CI runner). They are never reached at runtime: release.LauncherSidecarURL()
// returns "" there, so Outdated/UpdateSelf bail out before calling any of them.

var errUnsupported = fmt.Errorf("launcher self-update is unsupported on this platform")

func selfTarget() (string, error) { return "", errUnsupported }

func stageNewLauncher(string, string, download.Progress) (string, func(), error) {
	return "", nil, errUnsupported
}

func postSwap(string) {}

func reExec(string) error { return errUnsupported }
