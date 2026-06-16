package main

import (
	"fmt"
	"os"
	"strings"

	"niceswarm-launcher/internal/config"
	"niceswarm-launcher/internal/download"
	"niceswarm-launcher/internal/install"
	"niceswarm-launcher/internal/release"
)

// runHeadless is the original windowless flow (check → update → launch → exit), kept
// for automation, scripted runs, and as a fallback where a window can't be shown. It
// is unchanged in behavior from the pre-GUI launcher.
func runHeadless(dataDir string, cfg config.Config) {
	target, err := release.Resolve(cfg.Debug)
	if err != nil {
		fatal("%v", err)
	}
	if cfg.Debug && !target.Debug {
		fmt.Println("note: a debug build is not published for this platform; using release.")
	}
	fmt.Printf("NiceSwarm launcher — %s\n", target.AssetFile)

	consoleCheckLauncher()

	if err := consoleEnsureUpdated(dataDir, target); err != nil {
		if install.Exists(dataDir, target) {
			fmt.Printf("update check failed (%v); launching the installed build.\n", err)
		} else {
			fatal("update failed and nothing is installed to run: %v", err)
		}
	}

	if err := install.Launch(install.LaunchTarget(dataDir, target)); err != nil {
		fatal("launch failed: %v", err)
	}
}

// consoleEnsureUpdated brings the install up to the latest published hash, if reachable.
func consoleEnsureUpdated(dataDir string, t release.Target) error {
	want, err := download.SidecarHash(t.SidecarURL(), sidecarTimeout)
	if err != nil {
		return fmt.Errorf("fetch checksum: %w", err)
	}
	if install.IsCurrent(dataDir, t, want) {
		fmt.Println("already up to date.")
		return nil
	}
	fmt.Println("downloading update…")
	if err := install.Apply(dataDir, t, want, consoleProgress()); err != nil {
		return err
	}
	fmt.Println("\nupdate installed.")
	return nil
}

// consoleCheckLauncher prints a notice if a newer launcher is published (detect-only;
// the GUI offers the actual self-update button). Best-effort and silent on failure.
func consoleCheckLauncher() {
	url := release.LauncherSidecarURL()
	if url == "" {
		return
	}
	want, err := download.SidecarHash(url, sidecarTimeout)
	if err != nil {
		return
	}
	exe, err := os.Executable()
	if err != nil {
		return
	}
	if local := download.HashFile(exe); local != "" && !strings.EqualFold(local, want) {
		fmt.Printf("note: a newer launcher is available — run without --headless to update, or get it from\n  %s\n", release.LauncherPage)
	}
}

func consoleProgress() download.Progress {
	return func(done, total int64) {
		if total > 0 {
			fmt.Printf("\r  %5.1f%%  (%d / %d bytes)        ", float64(done)/float64(total)*100, done, total)
		} else {
			fmt.Printf("\r  %d bytes        ", done)
		}
	}
}
