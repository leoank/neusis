package cmd

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"

	"github.com/leoank/neusis/cli/internal/scaffold"
)

// findRepoRoot walks up from start looking for a directory that holds
// both a flake.nix and a modules/ dir — the shape of a neusis fleet
// repo. Returns an error if none is found.
func findRepoRoot(start string) (string, error) {
	dir, err := filepath.Abs(start)
	if err != nil {
		return "", err
	}
	for {
		_, flakeErr := os.Stat(filepath.Join(dir, "flake.nix"))
		modInfo, modErr := os.Stat(filepath.Join(dir, "modules"))
		if flakeErr == nil && modErr == nil && modInfo.IsDir() {
			return dir, nil
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			return "", fmt.Errorf("not inside a neusis repo (no flake.nix + modules/ found); run `neusis init` first")
		}
		dir = parent
	}
}

// reportWritten prints what the writer created and skipped.
func reportWritten(out io.Writer, w *scaffold.Writer) {
	for _, p := range w.Written() {
		fmt.Fprintf(out, "  + %s\n", p)
	}
	for _, p := range w.Skipped() {
		fmt.Fprintf(out, "  · %s (exists, skipped)\n", p)
	}
}

// secretsEnabled reports whether a repo has agenix-rekey set up, keyed
// on the presence of secrets/master-identities.nix.
func secretsEnabled(root string) bool {
	_, err := os.Stat(filepath.Join(root, "secrets", "master-identities.nix"))
	return err == nil
}

var darwinInputRe = regexp.MustCompile(`(?m)^\s*darwin\s*=\s*\{`)

// hasDarwinInput reports whether the repo declares a `darwin` flake
// input (needed to build any nix-darwin host). Checks the generated
// flake.nix and, for dendritic repos, modules/dendritic.nix.
func hasDarwinInput(root string) bool {
	for _, rel := range []string{"flake.nix", filepath.Join("modules", "dendritic.nix")} {
		b, err := os.ReadFile(filepath.Join(root, rel))
		if err != nil {
			continue
		}
		if darwinInputRe.Match(b) {
			return true
		}
	}
	return false
}

// isDendritic reports whether the repo uses the dendritic (flake-file)
// style, keyed on modules/dendritic.nix.
func isDendritic(root string) bool {
	_, err := os.Stat(filepath.Join(root, "modules", "dendritic.nix"))
	return err == nil
}

// isTTY reports whether stdin looks interactive.
func isTTY() bool {
	fi, err := os.Stdin.Stat()
	if err != nil {
		return false
	}
	return fi.Mode()&os.ModeCharDevice != 0
}
