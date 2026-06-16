// Package macapp holds the shared macOS .app-bundle helpers: unzipping a downloaded
// archive (with a zip-slip guard), locating the .app inside it, finding the inner
// Mach-O whose SHA256 the sidecar publishes, and clearing Gatekeeper quarantine. Both
// the game install (internal/install) and the launcher self-update (internal/selfupdate)
// use these so there is a single source of truth for the bundle dance.
package macapp

import (
	"archive/zip"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// Unzip extracts src into dest, preserving file modes (the executable bit on the inner
// Mach-O matters) and guarding against zip-slip path escapes.
func Unzip(src, dest string) error {
	r, err := zip.OpenReader(src)
	if err != nil {
		return err
	}
	defer r.Close()
	prefix := filepath.Clean(dest) + string(os.PathSeparator)
	for _, f := range r.File {
		fp := filepath.Join(dest, f.Name)
		if !strings.HasPrefix(fp, prefix) { // zip-slip guard
			return fmt.Errorf("unsafe zip path %q", f.Name)
		}
		if f.FileInfo().IsDir() {
			if err := os.MkdirAll(fp, 0o755); err != nil {
				return err
			}
			continue
		}
		if err := os.MkdirAll(filepath.Dir(fp), 0o755); err != nil {
			return err
		}
		if err := extractOne(f, fp); err != nil {
			return err
		}
	}
	return nil
}

// extractOne writes one zip entry to dest, preserving its mode.
func extractOne(f *zip.File, dest string) error {
	rc, err := f.Open()
	if err != nil {
		return err
	}
	defer rc.Close()
	out, err := os.OpenFile(dest, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, f.Mode())
	if err != nil {
		return err
	}
	defer out.Close()
	_, err = io.Copy(out, rc)
	return err
}

// FindApp returns the first *.app directory under root, or an error if none is present.
func FindApp(root string) (string, error) {
	var found string
	err := filepath.WalkDir(root, func(p string, d os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() && strings.HasSuffix(d.Name(), ".app") {
			found = p
			return filepath.SkipAll
		}
		return nil
	})
	if err != nil {
		return "", err
	}
	if found == "" {
		return "", fmt.Errorf("no .app found in archive")
	}
	return found, nil
}

// InnerBinary returns the single executable in <app>/Contents/MacOS, or "" if the app
// isn't present. Godot/Gio name it after the product, so don't assume a fixed filename.
func InnerBinary(appPath string) (string, error) {
	dir := filepath.Join(appPath, "Contents", "MacOS")
	entries, err := os.ReadDir(dir)
	if err != nil {
		return "", nil // not installed yet
	}
	for _, e := range entries {
		if !e.IsDir() {
			return filepath.Join(dir, e.Name()), nil
		}
	}
	return "", nil
}

// ClearQuarantine best-effort removes the com.apple.quarantine xattr so the first launch
// isn't blocked by Gatekeeper. Any failure is ignored (the attribute may be absent).
func ClearQuarantine(appPath string) {
	_ = exec.Command("xattr", "-dr", "com.apple.quarantine", appPath).Run()
}
