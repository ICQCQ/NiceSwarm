// Package selfupdate replaces the running launcher with a freshly downloaded,
// hash-verified copy and re-execs it. Neither OS lets you clobber a running image in
// place, but both let you move it aside, so the swap is: move the target -> target.old
// (frees the path), move the new copy into place, re-exec, then delete the .old on the
// next startup. Any failure after the move rolls .old back, so a botched update never
// leaves the user without a working launcher.
//
// The "target" is the unit that gets swapped: the .exe on Windows, the whole .app
// bundle on macOS. Platform specifics (resolving the target, staging the download,
// re-exec) live in the build-tagged selfupdate_<os>.go files; this file holds the
// platform-agnostic move/rollback and the verify-then-swap orchestration.
package selfupdate

import (
	"fmt"
	"os"
	"strings"
	"time"

	"niceswarm-launcher/internal/download"
	"niceswarm-launcher/internal/release"
)

const (
	oldSuffix       = ".old"
	sidecarTimeout  = 10 * time.Second
	downloadTimeout = 30 * time.Minute
)

// OldPath returns the parked-backup path for a swap target.
func OldPath(target string) string { return target + oldSuffix }

// CleanupOld removes a parked <target>.old backup (file or directory). Best-effort and
// silent: right after a re-exec the old image may still be momentarily locked, in which
// case the following startup clears it.
func CleanupOld(target string) { _ = os.RemoveAll(OldPath(target)) }

// CleanupSelf sweeps the backup parked next to this launcher's swap target (the .exe on
// Windows, the .app on macOS) from a previous successful self-update. No-op if the
// target can't be resolved or no backup exists.
func CleanupSelf() {
	if t, err := selfTarget(); err == nil {
		CleanupOld(t)
	}
}

// Replace swaps dst (a file or directory) for src: move dst aside to dst.old, then move
// src into dst's place. On failure after the move, dst.old is restored so the caller is
// never left without a working launcher. src and dst MUST be on the same volume (the
// platform stagers download next to the target to guarantee this).
func Replace(dst, src string) error {
	backup := OldPath(dst)
	_ = os.RemoveAll(backup) // clear a stale backup so the move can't collide
	if err := os.Rename(dst, backup); err != nil {
		return fmt.Errorf("move running launcher aside: %w", err)
	}
	if err := os.Rename(src, dst); err != nil {
		// Roll back: put the working launcher back exactly where it was.
		if rbErr := os.Rename(backup, dst); rbErr != nil {
			return fmt.Errorf("install new launcher: %w (ROLLBACK FAILED: %v — restore %q manually)", err, rbErr, backup)
		}
		return fmt.Errorf("install new launcher: %w (rolled back, launcher intact)", err)
	}
	return nil
}

// Outdated reports whether a newer launcher than the running one is published. Silent on
// any failure (offline / unsupported platform) — returns false. The running executable
// (os.Executable()) is exactly what the sidecar hashes on both platforms: the .exe on
// Windows, the inner Mach-O on macOS.
func Outdated() bool {
	if release.LauncherSidecarURL() == "" {
		return false
	}
	exe, err := os.Executable()
	if err != nil {
		return false
	}
	want, err := download.SidecarHash(release.LauncherSidecarURL(), sidecarTimeout)
	if err != nil {
		return false
	}
	local := download.HashFile(exe)
	return local != "" && !strings.EqualFold(local, want)
}

// UpdateSelf downloads the newest launcher, verifies its published hash BEFORE any swap,
// replaces the running binary/bundle (with rollback), and re-execs the new copy. On
// success the process has handed off — the caller should exit. Any failure returns an
// error with the launcher left intact.
func UpdateSelf(prog download.Progress) error {
	url := release.LauncherSidecarURL()
	if url == "" {
		return fmt.Errorf("self-update isn't supported on this platform")
	}
	target, err := selfTarget()
	if err != nil {
		return err
	}
	want, err := download.SidecarHash(url, sidecarTimeout)
	if err != nil {
		return fmt.Errorf("fetch launcher checksum: %w", err)
	}
	newPath, cleanup, err := stageNewLauncher(target, want, prog)
	if cleanup != nil {
		defer cleanup()
	}
	if err != nil {
		return err
	}
	if err := Replace(target, newPath); err != nil {
		return err
	}
	postSwap(target) // e.g. clear quarantine on macOS
	if err := reExec(target); err != nil {
		return fmt.Errorf("updated, but relaunch failed (%w) — please reopen the launcher", err)
	}
	return nil
}
