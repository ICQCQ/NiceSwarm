package selfupdate

import (
	"os"
	"path/filepath"
	"testing"
)

// Replace must swap dst's bytes for src's and park the old image at dst.old.
func TestReplaceSwapsAndBacksUp(t *testing.T) {
	dir := t.TempDir()
	dst := filepath.Join(dir, "launcher.exe")
	src := filepath.Join(dir, "new.bin")
	if err := os.WriteFile(dst, []byte("OLD"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(src, []byte("NEW"), 0o755); err != nil {
		t.Fatal(err)
	}

	if err := Replace(dst, src); err != nil {
		t.Fatalf("Replace: %v", err)
	}
	if got, _ := os.ReadFile(dst); string(got) != "NEW" {
		t.Errorf("dst = %q, want NEW", got)
	}
	if got, _ := os.ReadFile(OldPath(dst)); string(got) != "OLD" {
		t.Errorf("backup = %q, want OLD (the parked running image)", got)
	}
}

// A failed copy (missing src) must roll the working launcher back into place — the
// caller must never be left with no launcher.
func TestReplaceRollsBackOnBadSrc(t *testing.T) {
	dir := t.TempDir()
	dst := filepath.Join(dir, "launcher.exe")
	if err := os.WriteFile(dst, []byte("OLD"), 0o755); err != nil {
		t.Fatal(err)
	}
	missing := filepath.Join(dir, "does-not-exist")

	if err := Replace(dst, missing); err == nil {
		t.Fatal("Replace with missing src: want error, got nil")
	}
	if got, _ := os.ReadFile(dst); string(got) != "OLD" {
		t.Errorf("after rollback dst = %q, want OLD (launcher restored intact)", got)
	}
	if _, err := os.Stat(OldPath(dst)); !os.IsNotExist(err) {
		t.Errorf("backup should not linger after rollback")
	}
}

// CleanupOld removes the parked backup and is a no-op when none exists.
func TestCleanupOld(t *testing.T) {
	dir := t.TempDir()
	exe := filepath.Join(dir, "launcher.exe")
	CleanupOld(exe) // no backup present: must not panic or error

	if err := os.WriteFile(OldPath(exe), []byte("stale"), 0o644); err != nil {
		t.Fatal(err)
	}
	CleanupOld(exe)
	if _, err := os.Stat(OldPath(exe)); !os.IsNotExist(err) {
		t.Errorf("CleanupOld did not remove the backup")
	}
}

// On macOS the swap target is a .app *directory*, so Replace + CleanupOld must handle
// directories (rename-based swap, RemoveAll cleanup), not just files.
func TestReplaceAndCleanupDirectory(t *testing.T) {
	dir := t.TempDir()
	dst := filepath.Join(dir, "App.app")
	src := filepath.Join(dir, "App-new.app")
	mustBundle := func(root, marker string) {
		inner := filepath.Join(root, "Contents", "MacOS")
		if err := os.MkdirAll(inner, 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(inner, "bin"), []byte(marker), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	mustBundle(dst, "OLD")
	mustBundle(src, "NEW")

	if err := Replace(dst, src); err != nil {
		t.Fatalf("Replace(dir): %v", err)
	}
	if got, _ := os.ReadFile(filepath.Join(dst, "Contents", "MacOS", "bin")); string(got) != "NEW" {
		t.Errorf("swapped bundle inner = %q, want NEW", got)
	}
	if _, err := os.Stat(OldPath(dst)); err != nil {
		t.Errorf("backup bundle should exist after a directory swap: %v", err)
	}

	// CleanupOld must remove the parked .app.old directory (os.Remove would fail on it).
	CleanupOld(dst)
	if _, err := os.Stat(OldPath(dst)); !os.IsNotExist(err) {
		t.Errorf("CleanupOld did not remove the .app.old directory")
	}
}
