// NiceSwarm launcher: a small Gio (gioui.org) windowed auto-updater. It keeps the
// locally-installed game binary matching the latest published build and launches it.
// Best-effort and offline-safe — Play never blocks on the network (if the update check
// fails but a build is installed, it still runs).
//
// Files: main.go (entry/flags) · controller.go (state + background workers) ·
// ui.go (Gio layout) · headless.go (the legacy console flow, behind --headless).
package main

import (
	"flag"
	"fmt"
	"log"
	"os"

	"gioui.org/app"

	"niceswarm-launcher/internal/config"
	"niceswarm-launcher/internal/install"
	"niceswarm-launcher/internal/selfupdate"
)

func main() {
	debugFlag := flag.Bool("debug", false, "select the debug game build (Windows x86_64 only)")
	releaseFlag := flag.Bool("release", false, "force the release build (overrides a stored debug preference)")
	headless := flag.Bool("headless", false, "no window: check, update, launch, exit (legacy console flow / automation)")
	flag.Parse()

	dataDir, err := install.DataDir()
	if err != nil {
		fatal("cannot determine data dir: %v", err)
	}

	// Sweep the parked backup left by a previous launcher self-update, if any.
	if exe, err := os.Executable(); err == nil {
		selfupdate.CleanupOld(exe)
	}

	// An explicit flag wins and is persisted; otherwise the stored value is used.
	cfg := config.Load(dataDir)
	switch {
	case *releaseFlag:
		cfg.Debug = false
		_ = config.Save(dataDir, cfg)
	case *debugFlag:
		cfg.Debug = true
		_ = config.Save(dataDir, cfg)
	}

	if *headless {
		runHeadless(dataDir, cfg)
		return
	}

	// Gio requires the event loop on its own goroutine and app.Main on the main one.
	go func() {
		if err := runGUI(dataDir, cfg); err != nil {
			log.Fatal(err)
		}
		os.Exit(0)
	}()
	app.Main()
}

func fatal(format string, a ...any) {
	fmt.Fprintf(os.Stderr, "error: "+format+"\n", a...)
	os.Exit(1)
}
