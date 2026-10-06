package anywhere

import (
	"bytes"
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestBuildNixosAnywhereArgs(t *testing.T) {
	opts := DeployOptions{
		DecryptOptions: DecryptOptions{
			TempFolder: "/tmp/custom_temp",
		},
		TargetHost:                "root@192.168.1.100",
		Flake:                     ".#my-host",
		SSHPort:                   2222,
		IdentityFile:              "~/.ssh/id_ed25519",
		CopyHostKeys:              true,
		PrintBuildLogs:            true,
		Debug:                     true,
		VMTest:                    true,
		BuildOnRemote:             true,
		NoSubstituteOnDestination: true,
		Kexec:                     "/path/to/kexec.tar.gz",
		ExtraArgs:                 []string{"--phases", "kexec,disko,install"},
	}

	args := BuildNixosAnywhereArgs(opts)
	cmdLine := strings.Join(args, " ")

	expectedSubstrings := []string{
		"--flake .#my-host",
		"--extra-files /tmp/custom_temp",
		"-t",
		"--ssh-port 2222",
		"-i ~/.ssh/id_ed25519",
		"--copy-host-keys",
		"--print-build-logs",
		"--debug",
		"--vm-test",
		"--build-on-remote",
		"--no-substitute-on-destination",
		"--kexec /path/to/kexec.tar.gz",
		"--phases kexec,disko,install",
		"root@192.168.1.100",
	}

	for _, sub := range expectedSubstrings {
		if !strings.Contains(cmdLine, sub) {
			t.Errorf("expected command line to contain %q, but got %q", sub, cmdLine)
		}
	}

	// Verify target host is the last argument
	if args[len(args)-1] != "root@192.168.1.100" {
		t.Errorf("expected target host to be last argument, got %q", args[len(args)-1])
	}
}

func TestWriteToTemp(t *testing.T) {
	tempDir := t.TempDir()
	extraFilesDir := t.TempDir()

	// 1. Test age file stripping
	ageFilePath := filepath.Join(extraFilesDir, "etc", "ssh", "ssh_host_ed25519_key.age")
	data := []byte("private-key-data")

	targetPath, err := WriteToTemp(data, ageFilePath, tempDir, extraFilesDir, true, 0600, nil)
	if err != nil {
		t.Fatalf("WriteToTemp failed: %v", err)
	}

	expectedPath := filepath.Join(tempDir, "etc", "ssh", "ssh_host_ed25519_key")
	if targetPath != expectedPath {
		t.Errorf("expected targetPath %q, got %q", expectedPath, targetPath)
	}

	content, err := os.ReadFile(targetPath)
	if err != nil {
		t.Fatalf("failed to read target file: %v", err)
	}
	if string(content) != "private-key-data" {
		t.Errorf("expected content %q, got %q", "private-key-data", string(content))
	}

	// 2. Test non-age file retaining suffix
	pubFilePath := filepath.Join(extraFilesDir, "etc", "ssh", "ssh_host_ed25519_key.pub")
	pubData := []byte("public-key-data")
	pubTargetPath, err := WriteToTemp(pubData, pubFilePath, tempDir, extraFilesDir, false, 0644, nil)
	if err != nil {
		t.Fatalf("WriteToTemp for pub key failed: %v", err)
	}

	expectedPubPath := filepath.Join(tempDir, "etc", "ssh", "ssh_host_ed25519_key.pub")
	if pubTargetPath != expectedPubPath {
		t.Errorf("expected pubTargetPath %q, got %q", expectedPubPath, pubTargetPath)
	}
}

func TestFixSSHKeyPermissions(t *testing.T) {
	tempDir := t.TempDir()
	sshDir := filepath.Join(tempDir, "etc", "ssh")
	if err := os.MkdirAll(sshDir, 0755); err != nil {
		t.Fatalf("mkdir failed: %v", err)
	}

	privKeyPath := filepath.Join(sshDir, "ssh_host_ed25519_key")
	pubKeyPath := filepath.Join(sshDir, "ssh_host_ed25519_key.pub")
	rsaPrivKeyPath := filepath.Join(sshDir, "ssh_host_rsa_key")
	otherFilePath := filepath.Join(sshDir, "sshd_config")

	if err := os.WriteFile(privKeyPath, []byte("priv"), 0777); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(pubKeyPath, []byte("pub"), 0777); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(rsaPrivKeyPath, []byte("rsa"), 0777); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(otherFilePath, []byte("config"), 0644); err != nil {
		t.Fatal(err)
	}

	var buf bytes.Buffer
	if err := FixSSHKeyPermissions(tempDir, &buf); err != nil {
		t.Fatalf("FixSSHKeyPermissions failed: %v", err)
	}

	privFi, _ := os.Stat(privKeyPath)
	if privFi.Mode().Perm() != 0600 {
		t.Errorf("expected private key permission 0600, got %o", privFi.Mode().Perm())
	}

	pubFi, _ := os.Stat(pubKeyPath)
	if pubFi.Mode().Perm() != 0644 {
		t.Errorf("expected public key permission 0644, got %o", pubFi.Mode().Perm())
	}

	rsaPrivFi, _ := os.Stat(rsaPrivKeyPath)
	if rsaPrivFi.Mode().Perm() != 0600 {
		t.Errorf("expected rsa private key permission 0600, got %o", rsaPrivFi.Mode().Perm())
	}
}

func TestCreateRootStructureValidation(t *testing.T) {
	ctx := context.Background()

	// Missing extra files folder
	err := CreateRootStructure(ctx, DecryptOptions{
		ExtraFilesFolder: "/path/that/does/not/exist/at/all",
		KeyPath:          "/dev/null",
	})
	if err == nil {
		t.Errorf("expected error for non-existent extra files folder")
	}

	// Extra files is not a directory
	tmpFile, err := os.CreateTemp("", "anywhere_test_*")
	if err != nil {
		t.Fatal(err)
	}
	defer os.Remove(tmpFile.Name())
	tmpFile.Close()

	err = CreateRootStructure(ctx, DecryptOptions{
		ExtraFilesFolder: tmpFile.Name(),
		KeyPath:          "/dev/null",
	})
	if err == nil {
		t.Errorf("expected error when extra files path is not a directory")
	}

	// Missing key
	tmpDir := t.TempDir()
	err = CreateRootStructure(ctx, DecryptOptions{
		ExtraFilesFolder: tmpDir,
		KeyPath:          "/path/to/nonexistent/key",
	})
	if err == nil {
		t.Errorf("expected error for non-existent key")
	}

	// Non-age files copied successfully
	fakeKey, err := os.CreateTemp("", "fake_key_*")
	if err != nil {
		t.Fatal(err)
	}
	defer os.Remove(fakeKey.Name())
	fakeKey.Close()

	subDir := filepath.Join(tmpDir, "etc", "ssh")
	if err := os.MkdirAll(subDir, 0755); err != nil {
		t.Fatal(err)
	}
	pubKeyPath := filepath.Join(subDir, "ssh_host_ed25519_key.pub")
	if err := os.WriteFile(pubKeyPath, []byte("ssh-ed25519 AAA..."), 0644); err != nil {
		t.Fatal(err)
	}

	destTemp := t.TempDir()
	var outBuf bytes.Buffer
	err = CreateRootStructure(ctx, DecryptOptions{
		ExtraFilesFolder: tmpDir,
		TempFolder:       destTemp,
		KeyPath:          fakeKey.Name(),
		Out:              &outBuf,
	})
	if err != nil {
		t.Fatalf("CreateRootStructure failed: %v", err)
	}

	copiedPub := filepath.Join(destTemp, "etc", "ssh", "ssh_host_ed25519_key.pub")
	content, err := os.ReadFile(copiedPub)
	if err != nil {
		t.Fatalf("failed to read copied pub key: %v", err)
	}
	if string(content) != "ssh-ed25519 AAA..." {
		t.Errorf("unexpected content: %s", string(content))
	}
}
