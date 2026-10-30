package doctor

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestDiagnoseMissingFlake(t *testing.T) {
	dir := t.TempDir()
	report, err := Diagnose(dir)
	if err != nil {
		t.Fatalf("Diagnose failed: %v", err)
	}

	if report.OK() {
		t.Fatal("expected report to fail when flake.nix is missing")
	}

	foundMissingFlake := false
	for _, cat := range report.Categories {
		for _, item := range cat.Items {
			if strings.Contains(item.Title, "Missing flake.nix") {
				foundMissingFlake = true
				if item.Status != StatusFail {
					t.Errorf("expected StatusFail, got %v", item.Status)
				}
			}
		}
	}
	if !foundMissingFlake {
		t.Error("expected item 'Missing flake.nix' in report")
	}
}

func TestDiagnoseHealthyRepo(t *testing.T) {
	dir := t.TempDir()

	// 1. flake.nix & lock
	mustWrite(t, filepath.Join(dir, "flake.nix"), `
{
  description = "Test Fleet";
  inputs = {
    darwin.url = "github:lnl7/nix-darwin";
  };
  outputs = inputs: import-tree ./modules;
}
`)
	mustWrite(t, filepath.Join(dir, "flake.lock"), `{}`)

	// 2. dendritic & systems
	mustWrite(t, filepath.Join(dir, "modules", "dendritic.nix"), `
{ flake-file.inputs = { darwin = {}; }; }
`)
	mustWrite(t, filepath.Join(dir, "modules", "systems.nix"), `
{
  inputs.neusis.lib.mkNeusisFlake {};
}
`)

	// 3. registry
	mustWrite(t, filepath.Join(dir, "modules", "registry", "home.nix"), `
{
  flake.neusis.registry.machines.home = {
    nixos = [ ];
    darwin = [ ];
  };
  flake.neusis.registry.users.home = {
    admins = [ ];
  };
  flake.neusis.registry.builders.home = [ ];
}
`)

	// 4. machine
	mustWrite(t, filepath.Join(dir, "modules", "machines", "box.nix"), `
{ self, ... }:
{
  flake.neusis.machines.box = {
    system = "x86_64-linux";
    hostname = "box";
    primaryUser = "alice";
    hostPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI...";
  };
  flake.neusis.registry.machines.home.nixos = [ self.neusis.machines.box ];
}
`)

	// 5. user + keys
	keyDir := filepath.Join(dir, "modules", "users", "keys")
	mustWrite(t, filepath.Join(keyDir, "alice.pub"), "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI...")
	mustWrite(t, filepath.Join(dir, "modules", "users", "alice.nix"), `
{ self, ... }:
{
  flake.neusis.users.alice.neusisOS = {
    sshKeys = [ ./keys/alice.pub ];
  };
  flake.neusis.registry.users.home.admins = [ self.neusis.users.alice.neusisOS ];
}
`)

	report, err := Diagnose(dir)
	if err != nil {
		t.Fatalf("Diagnose failed: %v", err)
	}

	if !report.OK() {
		var buf bytes.Buffer
		report.RenderText(&buf, true)
		t.Fatalf("expected healthy repo to pass, got failures:\n%s", buf.String())
	}
	if report.FailCount != 0 {
		t.Errorf("expected 0 failures, got %d", report.FailCount)
	}
}

func TestDiagnoseOrphanedMachine(t *testing.T) {
	dir := t.TempDir()

	mustWrite(t, filepath.Join(dir, "flake.nix"), `{}`)
	mustWrite(t, filepath.Join(dir, "modules", "systems.nix"), `{}`)
	mustWrite(t, filepath.Join(dir, "modules", "machines", "orphan.nix"), `
{
  flake.neusis.machines.orphan = {
    system = "x86_64-linux";
    hostname = "orphan";
    hostPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI...";
  };
}
`)
	mustWrite(t, filepath.Join(dir, "modules", "registry", "home.nix"), `
{
  flake.neusis.registry.machines.home.nixos = [ ];
  flake.neusis.registry.users.home.admins = [ ];
  flake.neusis.registry.builders.home = [ ];
}
`)

	report, err := Diagnose(dir)
	if err != nil {
		t.Fatalf("Diagnose failed: %v", err)
	}

	if report.OK() {
		t.Fatal("expected report to fail for orphaned machine")
	}

	foundOrphan := false
	for _, cat := range report.Categories {
		for _, item := range cat.Items {
			if strings.Contains(item.Title, `Machine "orphan" is defined but NOT in any machine registry`) {
				foundOrphan = true
				if item.Status != StatusFail {
					t.Errorf("expected StatusFail, got %v", item.Status)
				}
			}
		}
	}
	if !foundOrphan {
		t.Error("expected item detecting orphaned machine")
	}
}

func TestDiagnoseMissingDarwinInput(t *testing.T) {
	dir := t.TempDir()

	// Repo with NO darwin input declared
	mustWrite(t, filepath.Join(dir, "flake.nix"), `{ inputs = { nixpkgs = {}; }; }`)
	mustWrite(t, filepath.Join(dir, "modules", "systems.nix"), `{}`)
	mustWrite(t, filepath.Join(dir, "modules", "machines", "mac1.nix"), `
{ self, ... }:
{
  flake.neusis.machines.mac1 = {
    system = "aarch64-darwin";
    hostname = "mac1";
    hostPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI...";
  };
  flake.neusis.registry.machines.home.darwin = [ self.neusis.machines.mac1 ];
}
`)
	mustWrite(t, filepath.Join(dir, "modules", "registry", "home.nix"), `
{
  flake.neusis.registry.machines.home.darwin = [ ];
  flake.neusis.registry.users.home.admins = [ ];
  flake.neusis.registry.builders.home = [ ];
}
`)

	report, err := Diagnose(dir)
	if err != nil {
		t.Fatalf("Diagnose failed: %v", err)
	}

	if report.OK() {
		t.Fatal("expected report to fail for darwin machine without darwin input")
	}

	foundDarwinErr := false
	for _, cat := range report.Categories {
		for _, item := range cat.Items {
			if strings.Contains(item.Title, `Darwin machine "mac1" missing 'darwin' flake input`) {
				foundDarwinErr = true
				if item.Status != StatusFail {
					t.Errorf("expected StatusFail, got %v", item.Status)
				}
			}
		}
	}
	if !foundDarwinErr {
		t.Error("expected item detecting missing darwin input")
	}
}

func TestDiagnoseMissingUserSSHKey(t *testing.T) {
	dir := t.TempDir()

	mustWrite(t, filepath.Join(dir, "flake.nix"), `{}`)
	mustWrite(t, filepath.Join(dir, "modules", "systems.nix"), `{}`)
	mustWrite(t, filepath.Join(dir, "modules", "users", "bob.nix"), `
{ self, ... }:
{
  flake.neusis.users.bob.neusisOS = {
    sshKeys = [ ./keys/missing_bob.pub ];
  };
  flake.neusis.registry.users.home.admins = [ self.neusis.users.bob.neusisOS ];
}
`)
	mustWrite(t, filepath.Join(dir, "modules", "registry", "home.nix"), `
{
  flake.neusis.registry.machines.home.nixos = [ ];
  flake.neusis.registry.users.home.admins = [ ];
  flake.neusis.registry.builders.home = [ ];
}
`)

	report, err := Diagnose(dir)
	if err != nil {
		t.Fatalf("Diagnose failed: %v", err)
	}

	if report.OK() {
		t.Fatal("expected report to fail for missing user SSH key")
	}

	foundMissingKey := false
	for _, cat := range report.Categories {
		for _, item := range cat.Items {
			if strings.Contains(item.Title, `User "bob" references missing SSH key file`) {
				foundMissingKey = true
			}
		}
	}
	if !foundMissingKey {
		t.Error("expected item detecting missing SSH key file")
	}
}

func TestDiagnoseAgnosticHygiene(t *testing.T) {
	dir := t.TempDir()

	mustWrite(t, filepath.Join(dir, "flake.nix"), `{}`)
	mustWrite(t, filepath.Join(dir, "modules", "systems.nix"), `{}`)
	mustWrite(t, filepath.Join(dir, "modules", "agnosticModules", "service.nix"), `
{ config, pkgs, ... }:
{
  systemd.services.foo = {
    description = "Unguarded systemd";
  };
}
`)

	report, err := Diagnose(dir)
	if err != nil {
		t.Fatalf("Diagnose failed: %v", err)
	}

	foundGuardWarn := false
	for _, cat := range report.Categories {
		for _, item := range cat.Items {
			if strings.Contains(item.Title, `references systemd without guard`) {
				foundGuardWarn = true
				if item.Status != StatusWarn {
					t.Errorf("expected StatusWarn, got %v", item.Status)
				}
			}
		}
	}
	if !foundGuardWarn {
		t.Error("expected warning for unguarded systemd in agnostic module")
	}
}

func TestDiagnoseRegistryBuilders(t *testing.T) {
	dir := t.TempDir()

	mustWrite(t, filepath.Join(dir, "flake.nix"), `{}`)
	mustWrite(t, filepath.Join(dir, "modules", "systems.nix"), `{}`)
	mustWrite(t, filepath.Join(dir, "modules", "registry", "work.nix"), `
{
  flake.neusis.registry.machines.work.nixos = [ ];
  flake.neusis.registry.users.work.admins = [ ];
}
`)

	report, err := Diagnose(dir)
	if err != nil {
		t.Fatalf("Diagnose failed: %v", err)
	}

	foundBuildersWarn := false
	for _, cat := range report.Categories {
		for _, item := range cat.Items {
			if strings.Contains(item.Title, `does not seed builders`) {
				foundBuildersWarn = true
				if item.Status != StatusWarn {
					t.Errorf("expected StatusWarn, got %v", item.Status)
				}
			}
		}
	}
	if !foundBuildersWarn {
		t.Error("expected warning for registry without builders")
	}
}

func TestRenderOutputs(t *testing.T) {
	report := &Report{
		RepoRoot: "/test/repo",
	}
	report.AddItem("Test Cat", Item{
		Status: StatusPass,
		Title:  "Test passed",
	})
	report.AddItem("Test Cat", Item{
		Status:  StatusWarn,
		Title:   "Test warning",
		Message: "Details here",
		Remedy:  "Fix it",
	})

	// Text render
	var textBuf bytes.Buffer
	report.RenderText(&textBuf, true)
	textStr := textBuf.String()
	if !strings.Contains(textStr, "Neusis Fleet Doctor") || !strings.Contains(textStr, "Test warning") {
		t.Errorf("unexpected text output: %s", textStr)
	}

	// JSON render
	var jsonBuf bytes.Buffer
	if err := report.RenderJSON(&jsonBuf); err != nil {
		t.Fatalf("RenderJSON failed: %v", err)
	}
	var decoded Report
	if err := json.Unmarshal(jsonBuf.Bytes(), &decoded); err != nil {
		t.Fatalf("failed to decode JSON report: %v", err)
	}
	if decoded.RepoRoot != "/test/repo" || decoded.PassCount != 1 || decoded.WarnCount != 1 {
		t.Errorf("decoded JSON mismatch: %+v", decoded)
	}
}

func mustWrite(t *testing.T, path, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		t.Fatalf("mkdir failed: %v", err)
	}
	if err := os.WriteFile(path, []byte(strings.TrimSpace(content)), 0644); err != nil {
		t.Fatalf("writeFile failed: %v", err)
	}
}
