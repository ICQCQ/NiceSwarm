// Package download fetches release assets over HTTP and verifies SHA256 hashes.
// The default net/http client follows the 302 redirects GitHub uses to
// objects.githubusercontent.com, so no special redirect handling is needed.
package download

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"time"
)

// Progress is called periodically during a download. total is -1 when unknown.
type Progress func(done, total int64)

// SidecarHash GETs a "<sha256>  <filename>" sidecar and returns the lowercase hex hash.
func SidecarHash(url string, timeout time.Duration) (string, error) {
	resp, err := (&http.Client{Timeout: timeout}).Get(url)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("sidecar HTTP %d", resp.StatusCode)
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, 4096))
	if err != nil {
		return "", err
	}
	return parseSidecar(string(body))
}

// parseSidecar pulls the leading 64-hex-char token out of a sidecar's first field.
func parseSidecar(text string) (string, error) {
	fields := strings.Fields(strings.ToLower(strings.TrimSpace(text)))
	if len(fields) == 0 {
		return "", fmt.Errorf("empty sidecar")
	}
	h := fields[0]
	if len(h) != 64 {
		return "", fmt.Errorf("sidecar hash wrong length (%d)", len(h))
	}
	if _, err := hex.DecodeString(h); err != nil {
		return "", fmt.Errorf("sidecar hash not hex")
	}
	return h, nil
}

// FetchText GETs a small text resource (e.g. the VERSION.txt build-version label) and
// returns its trimmed contents. Capped read — these files are a single short line.
func FetchText(url string, timeout time.Duration) (string, error) {
	resp, err := (&http.Client{Timeout: timeout}).Get(url)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("text HTTP %d", resp.StatusCode)
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, 256))
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(body)), nil
}

// ToFile streams url to dest and returns the lowercase-hex SHA256 of the downloaded
// bytes (the caller compares it to the expected hash). On any transport error dest
// is removed.
func ToFile(url, dest string, timeout time.Duration, prog Progress) (string, error) {
	resp, err := (&http.Client{Timeout: timeout}).Get(url)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("download HTTP %d", resp.StatusCode)
	}
	f, err := os.Create(dest)
	if err != nil {
		return "", err
	}
	h := sha256.New()
	cw := &countWriter{total: resp.ContentLength, prog: prog}
	_, copyErr := io.Copy(io.MultiWriter(f, h, cw), resp.Body)
	closeErr := f.Close()
	if copyErr != nil {
		os.Remove(dest)
		return "", copyErr
	}
	if closeErr != nil {
		os.Remove(dest)
		return "", closeErr
	}
	if prog != nil {
		prog(cw.done, cw.total) // final 100% tick
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}

// HashFile returns the lowercase-hex SHA256 of a file, or "" if it can't be read.
func HashFile(path string) string {
	f, err := os.Open(path)
	if err != nil {
		return ""
	}
	defer f.Close()
	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return ""
	}
	return hex.EncodeToString(h.Sum(nil))
}

// countWriter tallies bytes written and emits throttled progress updates.
type countWriter struct {
	done, total int64
	prog        Progress
	lastEmit    time.Time
}

func (w *countWriter) Write(p []byte) (int, error) {
	w.done += int64(len(p))
	if w.prog != nil {
		now := time.Now()
		if now.Sub(w.lastEmit) > 100*time.Millisecond {
			w.prog(w.done, w.total)
			w.lastEmit = now
		}
	}
	return len(p), nil
}
