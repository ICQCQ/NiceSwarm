// NiceSwarm launcher: ensures the locally-installed game binary matches the latest
// published build, then launches it. Best-effort and offline-safe — a launch never
// blocks on the network (if the update check fails but a build is installed, it runs).
package main

import (
	"flag"
	"fmt"
	"os"
	"time"

	"niceswarm-launcher/internal/config"
	"niceswarm-launcher/internal/download"
	"niceswarm-launcher/internal/install"
	"niceswarm-launcher/internal/release"
)

const sidecarTimeout = 10 * time.Second

func main() {
	debugFlag := flag.Bool("debug", false, "install/run the debug game build (Windows x86_64 only)")
	releaseFlag := flag.Bool("release", false, "force the release build (overrides a stored debug preference)")
	flag.Parse()

	dataDir, err := install.DataDir()
	if err != nil {
		fatal("cannot determine data dir: %v", err)
	}

	// An explicit flag wins and is persisted; otherwise use the stored value.
	cfg := config.Load(dataDir)
	switch {
	case *releaseFlag:
		cfg.Debug = false
		_ = config.Save(dataDir, cfg)
	case *debugFlag:
		cfg.Debug = true
		_ = config.Save(dataDir, cfg)
	}

	target, err := release.Resolve(cfg.Debug)
	if err != nil {
		fatal("%v", err)
	}
	if cfg.Debug && !target.Debug {
		fmt.Println("note: a debug build is not published for this platform; using release.")
	}
	fmt.Printf("NiceSwarm launcher — %s\n", target.AssetFile)

	if err := ensureUpdated(dataDir, target); err != nil {
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

// ensureUpdated brings the install up to the latest published hash, if reachable.
func ensureUpdated(dataDir string, t release.Target) error {
	want, err := download.SidecarHash(t.SidecarURL(), sidecarTimeout)
	if err != nil {
		return fmt.Errorf("fetch checksum: %w", err)
	}
	if install.IsCurrent(dataDir, t, want) {
		fmt.Println("already up to date.")
		return nil
	}
	fmt.Println("downloading update…")
	if err := install.Apply(dataDir, t, want, progressBar()); err != nil {
		return err
	}
	fmt.Println("\nupdate installed.")
	return nil
}

func progressBar() download.Progress {
	return func(done, total int64) {
		if total > 0 {
			fmt.Printf("\r  %5.1f%%  (%d / %d bytes)        ", float64(done)/float64(total)*100, done, total)
		} else {
			fmt.Printf("\r  %d bytes        ", done)
		}
	}
}

func fatal(format string, a ...any) {
	fmt.Fprintf(os.Stderr, "error: "+format+"\n", a...)
	os.Exit(1)
}
