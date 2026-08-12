// Package wizard holds shared defaults, option catalogues, and small
// validation/help helpers used by the interactive forms. The help text
// mirrors the descriptions on the neusis option schema
// (lib/neusis-options.nix); a future revision will load it from an
// embedded snapshot refreshed from the neusis repo.
package wizard

import (
	"fmt"
	"regexp"
	"strings"
)

// Default flake refs and versions for a freshly generated repo. Kept in
// sync with neusis's own inputs (system-pkgs.nix / flakeModules).
const (
	DefaultNeusisRef    = "github:leoank/neusis"
	DefaultNixpkgsRef   = "github:nixos/nixpkgs/nixos-25.11"
	DefaultHMRef        = "github:nix-community/home-manager/release-25.11"
	DefaultDarwinRef    = "github:LnL7/nix-darwin/nix-darwin-25.11"
	DefaultStateVersion = "25.11"
	DefaultLab          = "home"
	DefaultStyle        = "dendritic"
)

// Systems offered in the machine wizard, with the platform each maps to.
var Systems = []struct {
	System, Platform, Label string
}{
	{"x86_64-linux", "nixos", "x86_64-linux — 64-bit Intel/AMD (NixOS)"},
	{"aarch64-linux", "nixos", "aarch64-linux — 64-bit ARM (NixOS)"},
	{"aarch64-darwin", "darwin", "aarch64-darwin — Apple Silicon (nix-darwin)"},
	{"x86_64-darwin", "darwin", "x86_64-darwin — Intel Mac (nix-darwin)"},
}

// Roles offered in the user wizard, with help mirroring neusisOS.
var Roles = []struct {
	Role, Help string
}{
	{"admin", "wheel/sudo, networkmanager, libvirtd, docker, podman"},
	{"regular", "libvirtd, docker, podman (no wheel/sudo)"},
	{"guest", "minimal privileges (input, podman, docker)"},
	{"locked", "account exists, data preserved, cannot login"},
}

// PlatformOf returns "darwin" for Darwin systems, else "nixos".
func PlatformOf(system string) string {
	if strings.HasSuffix(system, "darwin") {
		return "darwin"
	}
	return "nixos"
}

var identRe = regexp.MustCompile(`^[a-zA-Z_][a-zA-Z0-9_-]*$`)

// ValidateIdent checks that s is a safe attribute-name / filename atom.
func ValidateIdent(s string) error {
	if strings.TrimSpace(s) == "" {
		return fmt.Errorf("must not be empty")
	}
	if !identRe.MatchString(s) {
		return fmt.Errorf("must start with a letter/underscore and contain only letters, digits, - or _")
	}
	return nil
}

// ValidateNonEmpty requires a non-blank string.
func ValidateNonEmpty(s string) error {
	if strings.TrimSpace(s) == "" {
		return fmt.Errorf("must not be empty")
	}
	return nil
}
