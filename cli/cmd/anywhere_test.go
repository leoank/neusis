package cmd

import (
	"bytes"
	"testing"
)

func TestAnywhereCmdHelp(t *testing.T) {
	root := newRootCmd()
	var buf bytes.Buffer
	root.SetOut(&buf)
	root.SetErr(&buf)
	root.SetArgs([]string{"anywhere", "--help"})

	if err := root.Execute(); err != nil {
		t.Fatalf("anywhere --help failed: %v", err)
	}

	out := buf.String()
	if !bytes.Contains(buf.Bytes(), []byte("deploy")) || !bytes.Contains(buf.Bytes(), []byte("decrypt")) {
		t.Errorf("expected anywhere help to mention deploy and decrypt, got: %s", out)
	}
}

func TestAnywhereDeployCmdHelp(t *testing.T) {
	root := newRootCmd()
	var buf bytes.Buffer
	root.SetOut(&buf)
	root.SetErr(&buf)
	root.SetArgs([]string{"anywhere", "deploy", "--help"})

	if err := root.Execute(); err != nil {
		t.Fatalf("anywhere deploy --help failed: %v", err)
	}

	out := buf.String()
	expectedFlags := []string{
		"--flake",
		"--extra-files",
		"--ssh-port",
		"--identity-file",
		"--copy-host-keys",
		"--print-build-logs",
		"--debug",
		"--vm-test",
		"--build-on-remote",
		"--no-substitute-on-destination",
		"--kexec",
		"--key",
		"--temp-folder",
	}

	for _, flag := range expectedFlags {
		if !bytes.Contains(buf.Bytes(), []byte(flag)) {
			t.Errorf("expected anywhere deploy help to contain flag %q, got: %s", flag, out)
		}
	}
}

func TestAnywhereDecryptCmdHelp(t *testing.T) {
	root := newRootCmd()
	var buf bytes.Buffer
	root.SetOut(&buf)
	root.SetErr(&buf)
	root.SetArgs([]string{"anywhere", "decrypt", "--help"})

	if err := root.Execute(); err != nil {
		t.Fatalf("anywhere decrypt --help failed: %v", err)
	}

	out := buf.String()
	expectedFlags := []string{
		"--key",
		"--temp-folder",
	}

	for _, flag := range expectedFlags {
		if !bytes.Contains(buf.Bytes(), []byte(flag)) {
			t.Errorf("expected anywhere decrypt help to contain flag %q, got: %s", flag, out)
		}
	}
}
