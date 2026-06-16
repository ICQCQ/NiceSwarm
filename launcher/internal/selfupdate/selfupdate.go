// Package selfupdate replaces the running launcher executable with a freshly
// downloaded, hash-verified copy. On Windows a running .exe cannot be overwritten but
// it CAN be renamed, so the swap is: move self -> self.old (frees the locked name),
// write the new bytes to the original path, re-exec, then delete the .old on the next
// startup. Any failure after the rename rolls the .old back, so a botched update never
// leaves the user without a working launcher.
//
// The hash MUST be verified by the caller before calling Replace — this package only
// performs the file dance, never the trust decision.
package selfupdate

import (
	"fmt"
	"io"
	"os"
	"os/exec"
)

// oldSuffix is appended to the running exe when it is moved aside during a swap.
const oldSuffix = ".old"

// OldPath returns the parked-backup path for an executable.
func OldPath(exePath string) string { return exePath + oldSuffix }

// CleanupOld removes the leftover <exe>.old from a previous successful self-update.
// Best-effort and silent: right after a re-exec the old image may still be momentarily
// locked, in which case the following startup clears it.
func CleanupOld(exePath string) { _ = os.Remove(OldPath(exePath)) }

// Replace swaps the file at dst (the running launcher) for the verified file at src.
// dst is moved to dst.old first so the locked running image is freed, then the new
// bytes are copied into place. If the copy fails, dst.old is restored. src is left for
// the caller to remove. The dst.old backup is intentionally kept on success — it is
// still the locked running image; CleanupOld removes it next startup.
func Replace(dst, src string) error {
	backup := OldPath(dst)
	_ = os.Remove(backup) // clear a stale backup so the rename can't collide
	if err := os.Rename(dst, backup); err != nil {
		return fmt.Errorf("move running launcher aside: %w", err)
	}
	if err := copyFile(src, dst); err != nil {
		// Roll back: put the working launcher back exactly where it was.
		if rbErr := os.Rename(backup, dst); rbErr != nil {
			return fmt.Errorf("write new launcher: %w (ROLLBACK FAILED: %v — restore %q manually)", err, rbErr, backup)
		}
		return fmt.Errorf("write new launcher: %w (rolled back, launcher intact)", err)
	}
	return nil
}

// ReExec starts a fresh copy of the launcher at exePath with args, wired to the current
// std streams, and returns. The caller must exit afterwards so the now-renamed running
// image releases and the next process can clean up the .old backup.
func ReExec(exePath string, args []string) error {
	cmd := exec.Command(exePath, args...)
	cmd.Stdout, cmd.Stderr, cmd.Stdin = os.Stdout, os.Stderr, os.Stdin
	return cmd.Start()
}

func copyFile(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	out, err := os.OpenFile(dst, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0o755)
	if err != nil {
		return err
	}
	if _, err := io.Copy(out, in); err != nil {
		out.Close()
		return err
	}
	return out.Close()
}
