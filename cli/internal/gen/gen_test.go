package gen_test

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/leoank/neusis/cli/internal/gen"
	"github.com/leoank/neusis/cli/internal/scaffold"
	"github.com/leoank/neusis/cli/internal/tmpl"
)

func TestGenRegistry(t *testing.T) {
	t.Setenv("NEUSIS_CACHE_DIR", t.TempDir())
	tmp := t.TempDir()
	w := scaffold.New(tmp)

	err := gen.Registry(w, tmpl.Registry{Name: "work"})
	if err != nil {
		t.Fatalf("gen.Registry failed: %v", err)
	}

	content, err := os.ReadFile(filepath.Join(tmp, "modules", "registry", "work.nix"))
	if err != nil {
		t.Fatalf("failed to read generated registry file: %v", err)
	}
	s := string(content)

	if !strings.Contains(s, "flake.neusis.registry.machines.work") {
		t.Errorf("expected registry to contain machines.work, got:\n%s", s)
	}
	if !strings.Contains(s, "flake.neusis.registry.users.work") {
		t.Errorf("expected registry to contain users.work, got:\n%s", s)
	}
	if !strings.Contains(s, "flake.neusis.registry.builders.work = [ ];") {
		t.Errorf("expected registry to contain builders.work = [ ];, got:\n%s", s)
	}
}

func TestGenMachine(t *testing.T) {
	t.Setenv("NEUSIS_CACHE_DIR", t.TempDir())
	tmp := t.TempDir()
	w := scaffold.New(tmp)

	m := tmpl.Machine{
		Name:     "oppy",
		Hostname: "oppy",
		System:   "x86_64-linux",
		Platform: "nixos",
		Lab:      "work",
	}
	if err := gen.Machine(w, m); err != nil {
		t.Fatalf("gen.Machine failed: %v", err)
	}

	content, err := os.ReadFile(filepath.Join(tmp, "modules", "machines", "oppy.nix"))
	if err != nil {
		t.Fatalf("failed to read generated machine file: %v", err)
	}
	s := string(content)

	if !strings.Contains(s, "flake.neusis.registry.machines.work.nixos") {
		t.Errorf("expected machine to join registry.machines.work.nixos, got:\n%s", s)
	}
	if !strings.Contains(s, "userRegistries = [ self.neusis.registry.users.work ];") {
		t.Errorf("expected userRegistries to reference work, got:\n%s", s)
	}
}

func TestGenUser(t *testing.T) {
	t.Setenv("NEUSIS_CACHE_DIR", t.TempDir())
	tmp := t.TempDir()
	w := scaffold.New(tmp)

	u := tmpl.User{
		Name:     "alice",
		Username: "alice",
		FullName: "Alice",
		Shell:    "zsh",
		Role:     "admin",
		Lab:      "work",
	}
	if err := gen.User(w, u); err != nil {
		t.Fatalf("gen.User failed: %v", err)
	}

	content, err := os.ReadFile(filepath.Join(tmp, "modules", "users", "alice.nix"))
	if err != nil {
		t.Fatalf("failed to read generated user file: %v", err)
	}
	s := string(content)

	if !strings.Contains(s, "flake.neusis.registry.users.work.admins") {
		t.Errorf("expected user to join registry.users.work.admins, got:\n%s", s)
	}
}

func TestGenModule(t *testing.T) {
	t.Setenv("NEUSIS_OFFLINE", "1")
	t.Setenv("NEUSIS_CACHE_DIR", t.TempDir())
	tmpl.ResetCache()
	tmp := t.TempDir()
	w := scaffold.New(tmp)

	// Agnostic module
	if err := gen.Module(w, tmpl.Module{Name: "wireguard", Type: "agnostic", Description: "Wireguard VPN"}); err != nil {
		t.Fatalf("gen.Module agnostic failed: %v", err)
	}
	content, err := os.ReadFile(filepath.Join(tmp, "modules", "agnosticModules", "wireguard.nix"))
	if err != nil {
		t.Fatalf("failed to read generated agnostic module: %v", err)
	}
	if s := string(content); !strings.Contains(s, "flake.agnosticModules.wireguard") || !strings.Contains(s, "options.neusis.wireguard") {
		t.Errorf("unexpected agnostic module content:\n%s", s)
	}

	// Home module
	if err := gen.Module(w, tmpl.Module{Name: "my-app", Type: "home"}); err != nil {
		t.Fatalf("gen.Module home failed: %v", err)
	}
	content, err = os.ReadFile(filepath.Join(tmp, "modules", "homeModules", "my-app.nix"))
	if err != nil {
		t.Fatalf("failed to read generated home module: %v", err)
	}
	if s := string(content); !strings.Contains(s, "flake.homeModules.my-app") {
		t.Errorf("unexpected home module content:\n%s", s)
	}

	// NixOS module
	if err := gen.Module(w, tmpl.Module{Name: "my-srv", Type: "nixos"}); err != nil {
		t.Fatalf("gen.Module nixos failed: %v", err)
	}
	content, err = os.ReadFile(filepath.Join(tmp, "modules", "nixosModules", "my-srv.nix"))
	if err != nil {
		t.Fatalf("failed to read generated nixos module: %v", err)
	}
	if s := string(content); !strings.Contains(s, "flake.nixosModules.my-srv") {
		t.Errorf("unexpected nixos module content:\n%s", s)
	}

	// Darwin module
	if err := gen.Module(w, tmpl.Module{Name: "my-daemon", Type: "darwin"}); err != nil {
		t.Fatalf("gen.Module darwin failed: %v", err)
	}
	content, err = os.ReadFile(filepath.Join(tmp, "modules", "darwinModules", "my-daemon.nix"))
	if err != nil {
		t.Fatalf("failed to read generated darwin module: %v", err)
	}
	if s := string(content); !strings.Contains(s, "flake.darwinModules.my-daemon") {
		t.Errorf("unexpected darwin module content:\n%s", s)
	}
}

func TestGenPackage(t *testing.T) {
	t.Setenv("NEUSIS_OFFLINE", "1")
	t.Setenv("NEUSIS_CACHE_DIR", t.TempDir())
	tmpl.ResetCache()
	tmp := t.TempDir()
	w := scaffold.New(tmp)

	if err := gen.Package(w, tmpl.Package{Name: "mytool", Description: "A handy tool"}); err != nil {
		t.Fatalf("gen.Package failed: %v", err)
	}

	content, err := os.ReadFile(filepath.Join(tmp, "modules", "packages", "mytool", "mytool.nix"))
	if err != nil {
		t.Fatalf("failed to read generated package file: %v", err)
	}
	s := string(content)
	if !strings.Contains(s, "packages.mytool = pkgs.writeShellApplication") {
		t.Errorf("expected package to declare packages.mytool, got:\n%s", s)
	}
	if !strings.Contains(s, `description = "A handy tool";`) {
		t.Errorf("expected package to declare description, got:\n%s", s)
	}
}

func TestGenFeature(t *testing.T) {
	t.Setenv("NEUSIS_OFFLINE", "1")
	t.Setenv("NEUSIS_CACHE_DIR", t.TempDir())
	tmpl.ResetCache()
	tmp := t.TempDir()
	w := scaffold.New(tmp)

	// Agnostic feature
	if err := gen.Feature(w, tmpl.Feature{Name: "dev-tools", Type: "agnostic"}); err != nil {
		t.Fatalf("gen.Feature agnostic failed: %v", err)
	}
	content, err := os.ReadFile(filepath.Join(tmp, "modules", "features", "agnostic", "dev-tools.nix"))
	if err != nil {
		t.Fatalf("failed to read generated agnostic feature: %v", err)
	}
	if s := string(content); !strings.Contains(s, "flake.neusis.features.agnostic.dev-tools") {
		t.Errorf("unexpected agnostic feature content:\n%s", s)
	}

	// Darwin feature
	if err := gen.Feature(w, tmpl.Feature{Name: "desktop", Type: "darwin"}); err != nil {
		t.Fatalf("gen.Feature darwin failed: %v", err)
	}
	content, err = os.ReadFile(filepath.Join(tmp, "modules", "features", "darwin", "desktop.nix"))
	if err != nil {
		t.Fatalf("failed to read generated darwin feature: %v", err)
	}
	if s := string(content); !strings.Contains(s, "flake.neusis.features.darwin.desktop") {
		t.Errorf("unexpected darwin feature content:\n%s", s)
	}

	// NixOS feature
	if err := gen.Feature(w, tmpl.Feature{Name: "server", Type: "nixos"}); err != nil {
		t.Fatalf("gen.Feature nixos failed: %v", err)
	}
	content, err = os.ReadFile(filepath.Join(tmp, "modules", "features", "nixos", "server.nix"))
	if err != nil {
		t.Fatalf("failed to read generated nixos feature: %v", err)
	}
	if s := string(content); !strings.Contains(s, "flake.neusis.features.nixos.server") {
		t.Errorf("unexpected nixos feature content:\n%s", s)
	}

	// HM feature
	if err := gen.Feature(w, tmpl.Feature{Name: "neovim", Type: "hm"}); err != nil {
		t.Fatalf("gen.Feature hm failed: %v", err)
	}
	content, err = os.ReadFile(filepath.Join(tmp, "modules", "features", "hm", "neovim.nix"))
	if err != nil {
		t.Fatalf("failed to read generated hm feature: %v", err)
	}
	if s := string(content); !strings.Contains(s, "flake.neusis.features.hm.neovim") {
		t.Errorf("unexpected hm feature content:\n%s", s)
	}

	// Flake feature
	if err := gen.Feature(w, tmpl.Feature{Name: "ci", Type: "flake"}); err != nil {
		t.Fatalf("gen.Feature flake failed: %v", err)
	}
	content, err = os.ReadFile(filepath.Join(tmp, "modules", "features", "flake", "ci.nix"))
	if err != nil {
		t.Fatalf("failed to read generated flake feature: %v", err)
	}
	if s := string(content); !strings.Contains(s, "flake.neusis.features.flake.ci") {
		t.Errorf("unexpected flake feature content:\n%s", s)
	}
}
