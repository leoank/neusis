package cmd

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/leoank/neusis/cli/internal/tmpl"
)

func TestAddRegistryCmdHelp(t *testing.T) {
	root := newRootCmd()
	var buf bytes.Buffer
	root.SetOut(&buf)
	root.SetErr(&buf)
	root.SetArgs([]string{"add", "registry", "--help"})

	if err := root.Execute(); err != nil {
		t.Fatalf("add registry --help failed: %v", err)
	}

	out := buf.String()
	if !strings.Contains(out, "Add a registry (machine, user, and builders registries)") {
		t.Errorf("expected add registry help to mention builders registries, got: %s", out)
	}
}

func TestAddUserCmdHelp(t *testing.T) {
	root := newRootCmd()
	var buf bytes.Buffer
	root.SetOut(&buf)
	root.SetErr(&buf)
	root.SetArgs([]string{"add", "user", "--help"})

	if err := root.Execute(); err != nil {
		t.Fatalf("add user --help failed: %v", err)
	}

	out := buf.String()
	if !strings.Contains(out, "--registry") || !strings.Contains(out, "user registry to join") {
		t.Errorf("expected add user help to mention --registry flag, got: %s", out)
	}
	if !strings.Contains(out, "--lab") {
		t.Errorf("expected add user help to mention --lab alias, got: %s", out)
	}
}

func TestAddMachineCmdHelp(t *testing.T) {
	root := newRootCmd()
	var buf bytes.Buffer
	root.SetOut(&buf)
	root.SetErr(&buf)
	root.SetArgs([]string{"add", "machine", "--help"})

	if err := root.Execute(); err != nil {
		t.Fatalf("add machine --help failed: %v", err)
	}

	out := buf.String()
	if !strings.Contains(out, "--registry") || !strings.Contains(out, "machine registry to join") {
		t.Errorf("expected add machine help to mention --registry flag, got: %s", out)
	}
	if !strings.Contains(out, "--lab") {
		t.Errorf("expected add machine help to mention --lab alias, got: %s", out)
	}
}

func createTestRepo(t *testing.T) string {
	t.Setenv("NEUSIS_OFFLINE", "1")
	t.Setenv("NEUSIS_CACHE_DIR", t.TempDir())
	tmpl.ResetCache()
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "flake.nix"), []byte("{ }\n"), 0o644); err != nil {
		t.Fatalf("write flake.nix failed: %v", err)
	}
	if err := os.MkdirAll(filepath.Join(dir, "modules"), 0o755); err != nil {
		t.Fatalf("mkdir modules failed: %v", err)
	}
	return dir
}

func TestAddRegistryExecution(t *testing.T) {
	repoDir := createTestRepo(t)
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatalf("getwd: %v", err)
	}
	if err := os.Chdir(repoDir); err != nil {
		t.Fatalf("chdir: %v", err)
	}
	defer func() { _ = os.Chdir(origDir) }()

	root := newRootCmd()
	var buf bytes.Buffer
	root.SetOut(&buf)
	root.SetErr(&buf)
	root.SetArgs([]string{"add", "registry", "fleet"})

	if err := root.Execute(); err != nil {
		t.Fatalf("add registry failed: %v", err)
	}

	out := buf.String()
	if !strings.Contains(out, `Added registry "fleet" (machine, user, builders):`) {
		t.Errorf("expected output to report added registry, got: %s", out)
	}

	content, err := os.ReadFile(filepath.Join(repoDir, "modules", "registry", "fleet.nix"))
	if err != nil {
		t.Fatalf("failed to read created registry file: %v", err)
	}
	s := string(content)
	if !strings.Contains(s, "flake.neusis.registry.builders.fleet = [ ];") {
		t.Errorf("expected registry to contain builders list, got:\n%s", s)
	}
}

func TestAddUserExecution(t *testing.T) {
	t.Setenv("NEUSIS_CACHE_DIR", t.TempDir())
	repoDir := createTestRepo(t)
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatalf("getwd: %v", err)
	}
	if err := os.Chdir(repoDir); err != nil {
		t.Fatalf("chdir: %v", err)
	}
	defer func() { _ = os.Chdir(origDir) }()

	root := newRootCmd()
	var buf bytes.Buffer
	root.SetOut(&buf)
	root.SetErr(&buf)
	root.SetArgs([]string{"add", "user", "--yes", "--registry", "special", "bob"})

	if err := root.Execute(); err != nil {
		t.Fatalf("add user failed: %v", err)
	}

	out := buf.String()
	if !strings.Contains(out, `Added user "bob" (admin) to user registry "special":`) {
		t.Errorf("expected output to report added user to user registry, got: %s", out)
	}

	content, err := os.ReadFile(filepath.Join(repoDir, "modules", "users", "bob.nix"))
	if err != nil {
		t.Fatalf("failed to read created user file: %v", err)
	}
	s := string(content)
	if !strings.Contains(s, "flake.neusis.registry.users.special.admins") {
		t.Errorf("expected user to join registry.users.special.admins, got:\n%s", s)
	}
}

func TestAddMachineExecution(t *testing.T) {
	repoDir := createTestRepo(t)
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatalf("getwd: %v", err)
	}
	if err := os.Chdir(repoDir); err != nil {
		t.Fatalf("chdir: %v", err)
	}
	defer func() { _ = os.Chdir(origDir) }()

	root := newRootCmd()
	var buf bytes.Buffer
	root.SetOut(&buf)
	root.SetErr(&buf)
	root.SetArgs([]string{"add", "machine", "--yes", "--system", "x86_64-linux", "--registry", "special", "server01"})

	if err := root.Execute(); err != nil {
		t.Fatalf("add machine failed: %v", err)
	}

	out := buf.String()
	if !strings.Contains(out, `Added machine "server01" to machine registry "special":`) {
		t.Errorf("expected output to report added machine to machine registry, got: %s", out)
	}

	content, err := os.ReadFile(filepath.Join(repoDir, "modules", "machines", "server01.nix"))
	if err != nil {
		t.Fatalf("failed to read created machine file: %v", err)
	}
	s := string(content)
	if !strings.Contains(s, "flake.neusis.registry.machines.special.nixos") {
		t.Errorf("expected machine to join registry.machines.special.nixos, got:\n%s", s)
	}
}

func TestAddModuleCmdHelp(t *testing.T) {
	root := newRootCmd()
	var buf bytes.Buffer
	root.SetOut(&buf)
	root.SetErr(&buf)
	root.SetArgs([]string{"add", "module", "--help"})

	if err := root.Execute(); err != nil {
		t.Fatalf("add module --help failed: %v", err)
	}

	out := buf.String()
	if !strings.Contains(out, "Add a reusable module") {
		t.Errorf("expected add module help to mention reusable module, got: %s", out)
	}
	if !strings.Contains(out, "--type") {
		t.Errorf("expected add module help to mention --type flag, got: %s", out)
	}
}

func TestAddPackageCmdHelp(t *testing.T) {
	root := newRootCmd()
	var buf bytes.Buffer
	root.SetOut(&buf)
	root.SetErr(&buf)
	root.SetArgs([]string{"add", "package", "--help"})

	if err := root.Execute(); err != nil {
		t.Fatalf("add package --help failed: %v", err)
	}

	out := buf.String()
	if !strings.Contains(out, "Add a flake package") {
		t.Errorf("expected add package help to mention flake package, got: %s", out)
	}
}

func TestAddFeatureCmdHelp(t *testing.T) {
	root := newRootCmd()
	var buf bytes.Buffer
	root.SetOut(&buf)
	root.SetErr(&buf)
	root.SetArgs([]string{"add", "feature", "--help"})

	if err := root.Execute(); err != nil {
		t.Fatalf("add feature --help failed: %v", err)
	}

	out := buf.String()
	if !strings.Contains(out, "Add an opt-in feature bundle") {
		t.Errorf("expected add feature help to mention feature bundle, got: %s", out)
	}
	if !strings.Contains(out, "--type") {
		t.Errorf("expected add feature help to mention --type flag, got: %s", out)
	}
}

func TestAddModuleExecution(t *testing.T) {
	repoDir := createTestRepo(t)
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatalf("getwd: %v", err)
	}
	if err := os.Chdir(repoDir); err != nil {
		t.Fatalf("chdir: %v", err)
	}
	defer func() { _ = os.Chdir(origDir) }()

	root := newRootCmd()
	var buf bytes.Buffer
	root.SetOut(&buf)
	root.SetErr(&buf)
	root.SetArgs([]string{"add", "module", "--yes", "--type", "agnostic", "wireguard"})

	if err := root.Execute(); err != nil {
		t.Fatalf("add module failed: %v", err)
	}

	out := buf.String()
	if !strings.Contains(out, `Added agnostic module "wireguard":`) {
		t.Errorf("expected output to report added module, got: %s", out)
	}

	content, err := os.ReadFile(filepath.Join(repoDir, "modules", "agnosticModules", "wireguard.nix"))
	if err != nil {
		t.Fatalf("failed to read created module file: %v", err)
	}
	if !strings.Contains(string(content), "flake.agnosticModules.wireguard") {
		t.Errorf("expected file to declare agnostic module, got:\n%s", string(content))
	}
}

func TestAddPackageExecution(t *testing.T) {
	repoDir := createTestRepo(t)
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatalf("getwd: %v", err)
	}
	if err := os.Chdir(repoDir); err != nil {
		t.Fatalf("chdir: %v", err)
	}
	defer func() { _ = os.Chdir(origDir) }()

	root := newRootCmd()
	var buf bytes.Buffer
	root.SetOut(&buf)
	root.SetErr(&buf)
	root.SetArgs([]string{"add", "package", "--yes", "mycli"})

	if err := root.Execute(); err != nil {
		t.Fatalf("add package failed: %v", err)
	}

	out := buf.String()
	if !strings.Contains(out, `Added package "mycli":`) {
		t.Errorf("expected output to report added package, got: %s", out)
	}

	content, err := os.ReadFile(filepath.Join(repoDir, "modules", "packages", "mycli", "mycli.nix"))
	if err != nil {
		t.Fatalf("failed to read created package file: %v", err)
	}
	if !strings.Contains(string(content), "packages.mycli = pkgs.writeShellApplication") {
		t.Errorf("expected file to declare packages.mycli, got:\n%s", string(content))
	}
}

func TestAddFeatureExecution(t *testing.T) {
	repoDir := createTestRepo(t)
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatalf("getwd: %v", err)
	}
	if err := os.Chdir(repoDir); err != nil {
		t.Fatalf("chdir: %v", err)
	}
	defer func() { _ = os.Chdir(origDir) }()

	root := newRootCmd()
	var buf bytes.Buffer
	root.SetOut(&buf)
	root.SetErr(&buf)
	root.SetArgs([]string{"add", "feature", "--yes", "--type", "darwin", "system-defaults"})

	if err := root.Execute(); err != nil {
		t.Fatalf("add feature failed: %v", err)
	}

	out := buf.String()
	if !strings.Contains(out, `Added darwin feature "system-defaults":`) {
		t.Errorf("expected output to report added feature, got: %s", out)
	}

	content, err := os.ReadFile(filepath.Join(repoDir, "modules", "features", "darwin", "system-defaults.nix"))
	if err != nil {
		t.Fatalf("failed to read created feature file: %v", err)
	}
	if !strings.Contains(string(content), "flake.neusis.features.darwin.system-defaults") {
		t.Errorf("expected file to declare darwin feature, got:\n%s", string(content))
	}
}
