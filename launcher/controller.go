package main

import (
	"os"
	"sync"
	"time"

	"gioui.org/app"

	"niceswarm-launcher/internal/config"
	"niceswarm-launcher/internal/download"
	"niceswarm-launcher/internal/install"
	"niceswarm-launcher/internal/release"
	"niceswarm-launcher/internal/selfupdate"
)

const sidecarTimeout = 10 * time.Second

// controller holds the launcher's mutable UI state, written by background workers and
// read by the Gio frame layout. All field access goes through mu; workers call
// w.Invalidate() after a mutation so the next frame reflects it. The single-worker
// invariant is enforced by tryStart (mutex-guarded), so two operations never overlap.
type controller struct {
	w       *app.Window
	dataDir string

	mu               sync.Mutex
	status           string
	progress         float32 // 0..1 during a download; <0 = no determinate bar
	busy             bool
	ready            bool // a runnable game build is installed -> Play enabled
	target           release.Target
	launcherOutdated bool
}

func newController(w *app.Window, dataDir string, cfg config.Config) *controller {
	c := &controller{w: w, dataDir: dataDir, progress: -1, status: "Starting…"}
	c.target, _ = release.Resolve(cfg.Debug)
	return c
}

// state is an immutable snapshot the layout renders from.
type state struct {
	status           string
	progress         float32
	busy, ready      bool
	launcherOutdated bool
	target           release.Target
}

func (c *controller) state() state {
	c.mu.Lock()
	defer c.mu.Unlock()
	return state{c.status, c.progress, c.busy, c.ready, c.launcherOutdated, c.target}
}

// update mutates state under the lock and requests a redraw.
func (c *controller) update(fn func()) {
	c.mu.Lock()
	fn()
	c.mu.Unlock()
	c.w.Invalidate()
}

// tryStart atomically claims the single worker slot. It returns false if an operation
// is already running, so callers can ignore the click. On success it sets the initial
// status; the worker must clear busy when it finishes (or exit the process).
func (c *controller) tryStart(status string) bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.busy {
		return false
	}
	c.busy = true
	c.progress = -1
	c.status = status
	c.w.Invalidate()
	return true
}

func (c *controller) finish() { c.update(func() { c.busy = false; c.progress = -1 }) }

// progressFn pushes download progress (0..1, or <0 when length is unknown) into the bar.
func (c *controller) progressFn() download.Progress {
	return func(done, total int64) {
		p := float32(-1)
		if total > 0 {
			p = float32(done) / float32(total)
		}
		c.update(func() { c.progress = p })
	}
}

// checkAndUpdate resolves the target for debug mode, fetches the sidecar, and
// downloads+installs if the local build differs. Offline-safe: if the network fails
// but a build is installed, Play is still enabled. Assumes tryStart already claimed
// the worker slot; runs in its own goroutine.
func (c *controller) checkAndUpdate(debug bool) {
	defer c.finish()
	c.update(func() { c.ready = false })

	t, err := release.Resolve(debug)
	if err != nil {
		c.update(func() { c.status = "Unsupported platform: " + err.Error() })
		return
	}
	c.update(func() { c.target = t })

	want, err := download.SidecarHash(t.SidecarURL(), sidecarTimeout)
	if err != nil {
		if install.Exists(c.dataDir, t) {
			c.update(func() { c.ready = true; c.status = "Offline — installed build ready to play." })
		} else {
			c.update(func() { c.status = "Can't reach the update server, and nothing is installed yet." })
		}
		return
	}
	if install.IsCurrent(c.dataDir, t, want) {
		c.update(func() { c.ready = true; c.status = "Up to date — ready to play." })
		return
	}

	c.update(func() { c.status = "Downloading " + t.AssetFile + " …"; c.progress = 0 })
	if err := install.Apply(c.dataDir, t, want, c.progressFn()); err != nil {
		if install.Exists(c.dataDir, t) {
			c.update(func() {
				c.ready = true
				c.status = "Update failed (" + err.Error() + ") — existing build is playable."
			})
		} else {
			c.update(func() { c.status = "Update failed: " + err.Error() })
		}
		return
	}
	c.update(func() { c.ready = true; c.status = "Updated — ready to play." })
}

// checkLauncher flags launcherOutdated when a newer launcher binary is published.
// Silent on any failure (offline / unsupported platform). Runs in its own goroutine and
// does NOT claim the worker slot (it is read-only and harmless to overlap a game check).
func (c *controller) checkLauncher() {
	if selfupdate.Outdated() {
		c.update(func() { c.launcherOutdated = true })
	}
}

// play launches the installed game and exits the launcher. Assumes the worker slot is
// claimed (so it can't race a download); on launch failure it releases the slot.
func (c *controller) play() {
	st := c.state()
	if err := install.Launch(install.LaunchTarget(c.dataDir, st.target)); err != nil {
		c.update(func() { c.busy = false; c.status = "Launch failed: " + err.Error() })
		return
	}
	os.Exit(0)
}

// updateLauncher downloads the newest launcher, verifies its hash, swaps the running
// binary/bundle (with rollback), and re-execs — all inside internal/selfupdate, which
// owns the per-OS dance. Gated behind an explicit button. Assumes the worker slot is
// claimed; runs in its own goroutine. On success the process has handed off → exit.
func (c *controller) updateLauncher() {
	defer c.finish()
	if err := selfupdate.UpdateSelf(c.progressFn()); err != nil {
		c.update(func() { c.status = err.Error() })
		return
	}
	os.Exit(0)
}
