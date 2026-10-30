package cmd

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestDoctorCmdHelp(t *testing.T) {
	root := newRootCmd()
	var buf bytes.Buffer
	root.SetOut(&buf)
	root.SetErr(&buf)
	root.SetArgs([]string{"doctor", "--help"})

	if err := root.Execute(); err != nil {
		t.Fatalf("doctor --help failed: %v", err)
	}

	out := buf.String()
	if !strings.Contains(out, "health, convention drift") {
		t.Errorf("expected doctor help to mention health, convention drift, got: %s", out)
	}
	if !strings.Contains(out, "--strict") || !strings.Contains(out, "--json") {
		t.Errorf("expected doctor help to mention --strict and --json flags, got: %s", out)
	}
}

func TestDoctorCmdHealthy(t *testing.T) {
	dir := t.TempDir()

	// Setup minimal healthy repo
	mustWriteFile(t, filepath.Join(dir, "flake.nix"), `
{
  inputs.darwin.url = "github:lnl7/nix-darwin";
  outputs = inputs: {};
}
`)
	mustWriteFile(t, filepath.Join(dir, "flake.lock"), `{}`)
	mustWriteFile(t, filepath.Join(dir, "modules", "systems.nix"), `{}`)
	mustWriteFile(t, filepath.Join(dir, "modules", "registry", "home.nix"), `
{
  flake.neusis.registry.machines.home.nixos = [ ];
  flake.neusis.registry.users.home.admins = [ ];
  flake.neusis.registry.builders.home = [ ];
}
`)

	root := newRootCmd()
	var buf bytes.Buffer
	root.SetOut(&buf)
	root.SetErr(&buf)
	root.SetArgs([]string{"doctor", dir})

	if err := root.Execute(); err != nil {
		t.Fatalf("expected doctor on healthy repo to pass, got: %v\nOutput: %s", err, buf.String())
	}

	out := buf.String()
	if !strings.Contains(out, "Result: Repository is healthy.") {
		t.Errorf("expected output to report healthy, got: %s", out)
	}
}

func TestDoctorCmdJSON(t *testing.T) {
	dir := t.TempDir()

	mustWriteFile(t, filepath.Join(dir, "flake.nix"), `{}`)
	mustWriteFile(t, filepath.Join(dir, "modules", "systems.nix"), `{}`)
	mustWriteFile(t, filepath.Join(dir, "modules", "registry", "home.nix"), `
{
  flake.neusis.registry.machines.home.nixos = [ ];
  flake.neusis.registry.users.home.admins = [ ];
  flake.neusis.registry.builders.home = [ ];
}
`)

	root := newRootCmd()
	var buf bytes.Buffer
	root.SetOut(&buf)
	root.SetErr(&buf)
	root.SetArgs([]string{"doctor", dir, "--json"})

	_ = root.Execute()

	var data map[string]any
	if err := json.Unmarshal(buf.Bytes(), &data); err != nil {
		t.Fatalf("expected valid JSON output, got error %v; output: %s", err, buf.String())
	}
	if _, ok := data["repoRoot"]; !ok {
		t.Errorf("expected 'repoRoot' in JSON output, got: %v", data)
	}
}

func TestDoctorCmdFailsOnIssues(t *testing.T) {
	dir := t.TempDir() // empty dir: missing flake.nix and modules/

	root := newRootCmd()
	var buf bytes.Buffer
	root.SetOut(&buf)
	root.SetErr(&buf)
	root.SetArgs([]string{"doctor", dir})

	err := root.Execute()
	if err == nil {
		t.Fatal("expected doctor to fail on empty directory without flake.nix")
	}

	out := buf.String()
	if !strings.Contains(out, "Missing flake.nix") {
		t.Errorf("expected output to mention Missing flake.nix, got: %s", out)
	}
}

func TestDoctorCmdStrict(t *testing.T) {
	dir := t.TempDir()

	mustWriteFile(t, filepath.Join(dir, "flake.nix"), `{}`)
	mustWriteFile(t, filepath.Join(dir, "modules", "systems.nix"), `{}`)
	// Notice: missing flake.lock triggers a warning
	mustWriteFile(t, filepath.Join(dir, "modules", "registry", "home.nix"), `
{
  flake.neusis.registry.machines.home.nixos = [ ];
  flake.neusis.registry.users.home.admins = [ ];
  flake.neusis.registry.builders.home = [ ];
}
`)

	// Non-strict: passes because there are no failures (only warnings)
	rootNonStrict := newRootCmd()
	var bufNonStrict bytes.Buffer
	rootNonStrict.SetOut(&bufNonStrict)
	rootNonStrict.SetErr(&bufNonStrict)
	rootNonStrict.SetArgs([]string{"doctor", dir})

	if err := rootNonStrict.Execute(); err != nil {
		t.Fatalf("expected non-strict doctor to pass with only warnings, got: %v", err)
	}

	// Strict: fails because of warning (missing flake.lock)
	rootStrict := newRootCmd()
	var bufStrict bytes.Buffer
	rootStrict.SetOut(&bufStrict)
	rootStrict.SetErr(&bufStrict)
	rootStrict.SetArgs([]string{"doctor", dir, "--strict"})

	if err := rootStrict.Execute(); err == nil {
		t.Fatal("expected strict doctor to fail when warnings exist")
	}
}

func mustWriteFile(t *testing.T, path, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		t.Fatalf("mkdir failed: %v", err)
	}
	if err := os.WriteFile(path, []byte(strings.TrimSpace(content)), 0644); err != nil {
		t.Fatalf("writeFile failed: %v", err)
	}
}
