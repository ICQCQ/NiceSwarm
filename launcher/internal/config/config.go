// Package config persists launcher preferences (currently just the debug toggle)
// to launcher.json in the per-user data dir, so an explicit --debug/--release flag
// sticks across runs.
package config

import (
	"encoding/json"
	"os"
	"path/filepath"
)

const fileName = "launcher.json"

// Config is the persisted launcher preference set.
type Config struct {
	Debug bool `json:"debug"`
}

func path(dataDir string) string { return filepath.Join(dataDir, fileName) }

// Load reads the config; a missing or corrupt file yields defaults (no error).
func Load(dataDir string) Config {
	var c Config
	b, err := os.ReadFile(path(dataDir))
	if err != nil {
		return c
	}
	_ = json.Unmarshal(b, &c) // best-effort: a malformed file falls back to defaults
	return c
}

// Save writes the config, creating the data dir if needed.
func Save(dataDir string, c Config) error {
	if err := os.MkdirAll(dataDir, 0o755); err != nil {
		return err
	}
	b, err := json.MarshalIndent(c, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path(dataDir), b, 0o644)
}
