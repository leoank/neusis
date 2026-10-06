package anywhere

import (
	"context"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// DefaultTempFolder is the default temporary folder used to assemble decrypted extra files.
const DefaultTempFolder = "/tmp/neusis_anywhere_temp"

// DefaultDecryptionKeyPath is the default path to the private SSH key used for age decryption.
const DefaultDecryptionKeyPath = "/etc/ssh/ssh_host_ed25519_key"

// DecryptOptions configures extra files preparation.
type DecryptOptions struct {
	ExtraFilesFolder string
	TempFolder       string
	KeyPath          string
	Out              io.Writer
	ErrOut           io.Writer
}

// DeployOptions configures nixos-anywhere deployment.
type DeployOptions struct {
	DecryptOptions

	TargetHost                string
	Flake                     string
	SSHPort                   int
	IdentityFile              string
	CopyHostKeys              bool
	PrintBuildLogs            bool
	Debug                     bool
	VMTest                    bool
	BuildOnRemote             bool
	NoSubstituteOnDestination bool
	Kexec                     string
	ExtraArgs                 []string

	Stdin  io.Reader
	Stdout io.Writer
	Stderr io.Writer
}

// DecryptAgeFile decrypts an age-encrypted file using the age binary.
func DecryptAgeFile(ctx context.Context, ageFilePath, keyPath string) ([]byte, error) {
	if _, err := exec.LookPath("age"); err != nil {
		return nil, fmt.Errorf("age not found in PATH: please install age (e.g. via nix shell nixpkgs#age or in neusis devShell)")
	}
	cmd := exec.CommandContext(ctx, "age", "--decrypt", "-i", keyPath, ageFilePath)
	out, err := cmd.Output()
	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			return nil, fmt.Errorf("error decrypting %s: %s", ageFilePath, strings.TrimSpace(string(exitErr.Stderr)))
		}
		return nil, fmt.Errorf("error decrypting %s: %w", ageFilePath, err)
	}
	return out, nil
}

// WriteToTemp writes data to a destination path under tempFolder maintaining the relative
// directory structure from extraFilesFolder. If removeAgeSuffix is true, a trailing .age
// extension is stripped from the relative path.
func WriteToTemp(data []byte, filePath, tempFolder, extraFilesFolder string, removeAgeSuffix bool, perm os.FileMode, out io.Writer) (string, error) {
	rel, err := filepath.Rel(extraFilesFolder, filePath)
	if err != nil {
		return "", fmt.Errorf("failed to compute relative path: %w", err)
	}

	targetRel := rel
	if removeAgeSuffix && strings.HasSuffix(targetRel, ".age") {
		targetRel = strings.TrimSuffix(targetRel, ".age")
	}

	targetPath := filepath.Join(tempFolder, targetRel)
	if err := os.MkdirAll(filepath.Dir(targetPath), 0755); err != nil {
		return "", fmt.Errorf("failed to create directory %s: %w", filepath.Dir(targetPath), err)
	}

	if perm == 0 {
		perm = 0644
	}
	if err := os.WriteFile(targetPath, data, perm); err != nil {
		return "", fmt.Errorf("failed to write %s: %w", targetPath, err)
	}

	if out != nil {
		fmt.Fprintf(out, "Written decrypted content to: %s\n", targetPath)
	}
	return targetPath, nil
}

// FixSSHKeyPermissions sets 0644 permissions on public SSH host keys (*.pub)
// and 0600 on private SSH host keys found within tempFolder.
func FixSSHKeyPermissions(tempFolder string, out io.Writer) error {
	return filepath.Walk(tempFolder, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() {
			return nil
		}
		name := info.Name()
		if matched, _ := filepath.Match("ssh_host_*_key.pub", name); matched {
			if err := os.Chmod(path, 0644); err != nil {
				return err
			}
			if out != nil {
				fmt.Fprintf(out, "Set permissions 644 for public key: %s\n", path)
			}
		} else if matched, _ := filepath.Match("ssh_host_*_key", name); matched {
			if err := os.Chmod(path, 0600); err != nil {
				return err
			}
			if out != nil {
				fmt.Fprintf(out, "Set permissions 600 for private key: %s\n", path)
			}
		}
		return nil
	})
}

// CreateRootStructure creates a directory hierarchy under tempFolder by decrypting all .age
// files from extraFilesFolder and copying any non-age files as-is. It then fixes SSH host
// key permissions.
func CreateRootStructure(ctx context.Context, opts DecryptOptions) error {
	out := opts.Out
	if out == nil {
		out = os.Stdout
	}
	errOut := opts.ErrOut
	if errOut == nil {
		errOut = os.Stderr
	}

	extraFilesFolder := opts.ExtraFilesFolder
	tempFolder := opts.TempFolder
	if tempFolder == "" {
		tempFolder = DefaultTempFolder
	}
	keyPath := opts.KeyPath
	if keyPath == "" {
		keyPath = DefaultDecryptionKeyPath
	}

	extraFi, err := os.Stat(extraFilesFolder)
	if err != nil {
		return fmt.Errorf("extra files folder %s does not exist: %w", extraFilesFolder, err)
	}
	if !extraFi.IsDir() {
		return fmt.Errorf("extra files path %s is not a directory", extraFilesFolder)
	}

	if _, err := os.Stat(keyPath); err != nil {
		return fmt.Errorf("decryption key %s does not exist: %w", keyPath, err)
	}

	if err := os.MkdirAll(tempFolder, 0755); err != nil {
		return fmt.Errorf("failed to create temp folder %s: %w", tempFolder, err)
	}

	var ageFiles []string
	var otherFiles []string

	err = filepath.Walk(extraFilesFolder, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() {
			return nil
		}
		if strings.HasSuffix(info.Name(), ".age") {
			ageFiles = append(ageFiles, path)
		} else {
			otherFiles = append(otherFiles, path)
		}
		return nil
	})
	if err != nil {
		return fmt.Errorf("failed to walk extra files folder %s: %w", extraFilesFolder, err)
	}

	if len(ageFiles) == 0 {
		fmt.Fprintf(out, "No .age files found in %s\n", extraFilesFolder)
	} else {
		fmt.Fprintf(out, "Found %d age files to decrypt\n", len(ageFiles))
		for _, ageFile := range ageFiles {
			fmt.Fprintf(out, "Decrypting: %s\n", ageFile)
			decrypted, err := DecryptAgeFile(ctx, ageFile, keyPath)
			if err != nil {
				fmt.Fprintf(errOut, "Failed to process %s: %v\n", ageFile, err)
				continue
			}
			if _, err := WriteToTemp(decrypted, ageFile, tempFolder, extraFilesFolder, true, 0600, out); err != nil {
				fmt.Fprintf(errOut, "Failed to write %s: %v\n", ageFile, err)
				continue
			}
		}
	}

	for _, file := range otherFiles {
		data, err := os.ReadFile(file)
		if err != nil {
			fmt.Fprintf(errOut, "Failed to read %s: %v\n", file, err)
			continue
		}
		info, _ := os.Stat(file)
		perm := os.FileMode(0644)
		if info != nil {
			perm = info.Mode().Perm()
		}
		if _, err := WriteToTemp(data, file, tempFolder, extraFilesFolder, false, perm, nil); err != nil {
			fmt.Fprintf(errOut, "Failed to write %s: %v\n", file, err)
			continue
		}
	}

	if err := FixSSHKeyPermissions(tempFolder, out); err != nil {
		return fmt.Errorf("failed to fix ssh key permissions in %s: %w", tempFolder, err)
	}

	fmt.Fprintf(out, "Root structure created in: %s\n", tempFolder)
	return nil
}

// BuildNixosAnywhereArgs constructs the argument list to pass to nixos-anywhere.
func BuildNixosAnywhereArgs(opts DeployOptions) []string {
	tempFolder := opts.TempFolder
	if tempFolder == "" {
		tempFolder = DefaultTempFolder
	}

	args := []string{
		"--flake", opts.Flake,
		"--extra-files", tempFolder,
		"-t",
	}

	if opts.SSHPort > 0 {
		args = append(args, "--ssh-port", fmt.Sprintf("%d", opts.SSHPort))
	}
	if opts.IdentityFile != "" {
		args = append(args, "-i", opts.IdentityFile)
	}
	if opts.CopyHostKeys {
		args = append(args, "--copy-host-keys")
	}
	if opts.PrintBuildLogs {
		args = append(args, "--print-build-logs")
	}
	if opts.Debug {
		args = append(args, "--debug")
	}
	if opts.VMTest {
		args = append(args, "--vm-test")
	}
	if opts.BuildOnRemote {
		args = append(args, "--build-on-remote")
	}
	if opts.NoSubstituteOnDestination {
		args = append(args, "--no-substitute-on-destination")
	}
	if opts.Kexec != "" {
		args = append(args, "--kexec", opts.Kexec)
	}
	if len(opts.ExtraArgs) > 0 {
		args = append(args, opts.ExtraArgs...)
	}

	args = append(args, opts.TargetHost)
	return args
}

// RunNixosAnywhere prepares the decrypted root structure and executes nixos-anywhere.
func RunNixosAnywhere(ctx context.Context, opts DeployOptions) error {
	out := opts.Stdout
	if out == nil {
		out = os.Stdout
	}
	errOut := opts.Stderr
	if errOut == nil {
		errOut = os.Stderr
	}
	in := opts.Stdin
	if in == nil {
		in = os.Stdin
	}

	// 1. Decrypt extra files into temp folder
	opts.DecryptOptions.Out = out
	opts.DecryptOptions.ErrOut = errOut
	if err := CreateRootStructure(ctx, opts.DecryptOptions); err != nil {
		return err
	}

	// 2. Look up nixos-anywhere binary
	if _, err := exec.LookPath("nixos-anywhere"); err != nil {
		return fmt.Errorf("nixos-anywhere not found in PATH: please install nixos-anywhere (e.g. via nix shell nixpkgs#nixos-anywhere or in neusis devShell)")
	}

	cmdArgs := BuildNixosAnywhereArgs(opts)
	fmt.Fprintf(out, "Running command: nixos-anywhere %s\n", strings.Join(cmdArgs, " "))

	cmd := exec.CommandContext(ctx, "nixos-anywhere", cmdArgs...)
	cmd.Stdin = in
	cmd.Stdout = out
	cmd.Stderr = errOut

	if err := cmd.Run(); err != nil {
		fmt.Fprintf(errOut, "nixos-anywhere failed: %v\n", err)
		return err
	}

	fmt.Fprintln(out, "nixos-anywhere completed successfully")
	return nil
}
