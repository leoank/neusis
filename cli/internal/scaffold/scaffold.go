// Package scaffold renders templates and writes files into a target
// repository. Writes are idempotent-friendly: existing files are never
// silently clobbered unless Force is set, and every written path is
// recorded so callers can report and stage them.
package scaffold

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"text/template"
)

// Writer renders templates into Root, collecting the paths it creates.
type Writer struct {
	Root    string
	Force   bool
	written []string
	skipped []string
}

// New returns a Writer rooted at dir.
func New(dir string) *Writer { return &Writer{Root: dir} }

// Written returns the repo-relative paths created, sorted.
func (w *Writer) Written() []string {
	out := append([]string(nil), w.written...)
	sort.Strings(out)
	return out
}

// Skipped returns the repo-relative paths left untouched because they
// already existed (and Force was false), sorted.
func (w *Writer) Skipped() []string {
	out := append([]string(nil), w.skipped...)
	sort.Strings(out)
	return out
}

// Render executes tmpl with data and writes the result to relPath under
// Root. A pre-existing file is skipped (recorded in Skipped) unless
// Force is set.
func (w *Writer) Render(relPath string, tmpl *template.Template, data any) error {
	var buf bytes.Buffer
	if err := tmpl.Execute(&buf, data); err != nil {
		return fmt.Errorf("render %s: %w", relPath, err)
	}
	return w.WriteFile(relPath, buf.Bytes())
}

// WriteFile writes raw bytes to relPath under Root, creating parent
// directories. A pre-existing file is skipped unless Force is set.
func (w *Writer) WriteFile(relPath string, content []byte) error {
	abs := filepath.Join(w.Root, relPath)
	if !w.Force {
		if _, err := os.Stat(abs); err == nil {
			w.skipped = append(w.skipped, relPath)
			return nil
		}
	}
	if err := os.MkdirAll(filepath.Dir(abs), 0o755); err != nil {
		return fmt.Errorf("mkdir for %s: %w", relPath, err)
	}
	if err := os.WriteFile(abs, content, 0o644); err != nil {
		return fmt.Errorf("write %s: %w", relPath, err)
	}
	w.written = append(w.written, relPath)
	return nil
}

// Exists reports whether relPath already exists under Root.
func (w *Writer) Exists(relPath string) bool {
	_, err := os.Stat(filepath.Join(w.Root, relPath))
	return err == nil
}
