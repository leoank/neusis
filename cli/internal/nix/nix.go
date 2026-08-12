// Package nix provides graceful, optional integration with the nix and
// git binaries. Every function degrades cleanly when the tool is
// absent: the CLI only ever *offers* to run these, never requires them.
package nix

import (
	"context"
	"os"
	"os/exec"
)

// Available reports whether a binary is resolvable on PATH.
func Available(bin string) bool {
	_, err := exec.LookPath(bin)
	return err == nil
}

// HasNix reports whether the nix binary is available.
func HasNix() bool { return Available("nix") }

// HasGit reports whether the git binary is available.
func HasGit() bool { return Available("git") }

// WriteFlake runs `nix run .#write-flake` in dir, streaming output to
// the current process's stdio. It returns an error if nix is missing or
// the command fails.
func WriteFlake(ctx context.Context, dir string) error {
	cmd := exec.CommandContext(ctx, "nix", "run", ".#write-flake")
	cmd.Dir = dir
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	return cmd.Run()
}

// GitAdd stages paths in dir. Untracked files are invisible to nix flake
// evaluation, so newly written modules must be staged before write-flake
// or any flake command will not see them.
func GitAdd(ctx context.Context, dir string, paths ...string) error {
	args := append([]string{"add", "--intent-to-add", "--"}, paths...)
	cmd := exec.CommandContext(ctx, "git", args...)
	cmd.Dir = dir
	return cmd.Run()
}

// GitInit initialises a git repository in dir if one does not already
// exist. Returns nil (no-op) when git is unavailable or already a repo.
func GitInit(ctx context.Context, dir string) error {
	if !HasGit() {
		return nil
	}
	if IsRepo(dir) {
		return nil
	}
	cmd := exec.CommandContext(ctx, "git", "init", "-q")
	cmd.Dir = dir
	return cmd.Run()
}

// IsRepo reports whether dir is inside a git working tree.
func IsRepo(dir string) bool {
	if !HasGit() {
		return false
	}
	cmd := exec.Command("git", "rev-parse", "--is-inside-work-tree")
	cmd.Dir = dir
	return cmd.Run() == nil
}
