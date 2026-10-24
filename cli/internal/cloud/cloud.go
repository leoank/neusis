// Package cloud bootstraps and deploys neusis cloud machines
// (docs/cloud-terranix-spec.md §5.4, §5.6).
//
// Bootstrap takes a freshly provisioned instance that booted the shared
// base image (root reachable by key) to the host's real configuration:
// it reads the instance IP from the stack's OpenTofu outputs, pushes the
// pre-generated host key from modules/secrets/bootstrap/<host>/ (decrypted
// with the operator's master identity, the same root-shaped tree the
// anywhere package handles), verifies the host now presents the key the
// registry pins, and runs nixos-rebuild switch against it. Deploy is the
// day-2 subset: nixos-rebuild switch over the tailnet.
package cloud

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/leoank/neusis/cli/internal/anywhere"
)

// Options configures a bootstrap run.
type Options struct {
	Host      string // neusis machine name (hostname)
	Stack     string // terranix stack holding the instance outputs
	IP        string // skip the tofu output lookup when set
	FlakeDir  string // repo root (the flake)
	KeyPath   string // master identity that decrypts the bootstrap tree
	SSHUser   string // user on the fresh instance (root on the base image)
	Timeout   time.Duration
	BuildHost bool // build on the target instead of locally

	Out, ErrOut io.Writer
}

// BootstrapDir is where the per-host root-shaped secret trees live,
// relative to the flake root.
const BootstrapDir = "modules/secrets/bootstrap"

// instanceOutputs mirrors the `instances` output of the oci-instance
// terranix module: { "<host>": { "public_ip": …, "ocid": …, … } }.
type instanceOutputs struct {
	Instances struct {
		Value map[string]map[string]string `json:"value"`
	} `json:"instances"`
}

// ParseInstanceIP extracts host's public IP from `tofu output -json`.
func ParseInstanceIP(outputJSON []byte, host string) (string, error) {
	var out instanceOutputs
	if err := json.Unmarshal(outputJSON, &out); err != nil {
		return "", fmt.Errorf("parsing tofu output: %w", err)
	}
	inst, ok := out.Instances.Value[host]
	if !ok {
		return "", fmt.Errorf("no instance %q in the stack outputs (known: %s)", host, strings.Join(keys(out.Instances.Value), ", "))
	}
	ip := inst["public_ip"]
	if ip == "" {
		return "", fmt.Errorf("instance %q has no public_ip output yet", host)
	}
	return ip, nil
}

// KeyFields reduces an OpenSSH public key line to "<type> <base64>" so
// keys compare regardless of comment.
func KeyFields(pub string) string {
	f := strings.Fields(pub)
	if len(f) < 2 {
		return strings.TrimSpace(pub)
	}
	return f[0] + " " + f[1]
}

// KnownHostsLine pins ip to the registry's host key for StrictHostKeyChecking.
func KnownHostsLine(ip, hostPubkey string) string {
	return ip + " " + KeyFields(hostPubkey) + "\n"
}

// NixosRebuildArgs assembles the nixos-rebuild invocation for host.
func NixosRebuildArgs(flakeDir, host, target string, buildOnTarget bool) []string {
	args := []string{"switch", "--flake", flakeDir + "#" + host, "--target-host", target}
	if buildOnTarget {
		args = append(args, "--build-host", target)
	}
	return args
}

// Run performs the bootstrap.
func Run(ctx context.Context, opts Options) error {
	out, errOut := writers(opts)
	if opts.Host == "" {
		return errors.New("host is required")
	}
	flakeDir, err := filepath.Abs(opts.FlakeDir)
	if err != nil {
		return err
	}
	if opts.SSHUser == "" {
		opts.SSHUser = "root"
	}
	if opts.Timeout == 0 {
		opts.Timeout = 10 * time.Minute
	}

	// 1. Where is it?
	ip := opts.IP
	if ip == "" {
		fmt.Fprintf(out, "Reading %s outputs of stack %s…\n", opts.Host, opts.Stack)
		raw, err := tofuOutput(ctx, flakeDir, opts.Stack, errOut)
		if err != nil {
			return err
		}
		if ip, err = ParseInstanceIP(raw, opts.Host); err != nil {
			return err
		}
	}
	target := opts.SSHUser + "@" + ip
	fmt.Fprintf(out, "Target: %s\n", target)

	// 2. Expected identity, from the registry.
	hostPubkey, err := nixEvalRaw(ctx, flakeDir, "neusis.machines."+opts.Host+".hostPubkey")
	if err != nil {
		return err
	}

	// 3. Wait for SSH on the fresh instance (unknown host key yet).
	fmt.Fprintf(out, "Waiting for SSH (up to %s)…\n", opts.Timeout)
	if err := waitForSSH(ctx, target, opts.Timeout); err != nil {
		return err
	}

	// 4. Decrypt the bootstrap tree with the master identity.
	tree := filepath.Join(flakeDir, BootstrapDir, opts.Host)
	if _, err := os.Stat(tree); err != nil {
		return fmt.Errorf("no bootstrap tree for %s at %s", opts.Host, tree)
	}
	tmp, err := os.MkdirTemp("", "neusis-cloud-"+opts.Host+"-")
	if err != nil {
		return err
	}
	defer os.RemoveAll(tmp)
	if err := anywhere.CreateRootStructure(ctx, anywhere.DecryptOptions{
		ExtraFilesFolder: tree, TempFolder: tmp, KeyPath: opts.KeyPath, Out: out, ErrOut: errOut,
	}); err != nil {
		return err
	}

	// 5. Push it, restart sshd so the host presents the pinned key.
	fmt.Fprintf(out, "Pushing host key to %s…\n", target)
	if err := pushTree(ctx, tmp, target, errOut); err != nil {
		return err
	}

	// 6. From here on, only talk to the host if it is the host we pinned.
	knownHosts := filepath.Join(tmp, "known_hosts")
	if err := os.WriteFile(knownHosts, []byte(KnownHostsLine(ip, hostPubkey)), 0o600); err != nil {
		return err
	}
	sshOpts := "-o UserKnownHostsFile=" + knownHosts + " -o StrictHostKeyChecking=yes"
	fmt.Fprintf(out, "Verifying the host key matches the registry…\n")
	if err := sshRun(ctx, target, strings.Fields(sshOpts), "true", errOut); err != nil {
		return fmt.Errorf("host key verification failed after push (%w): the instance does not present %s", err, KeyFields(hostPubkey))
	}

	// 7. Switch to the real configuration.
	args := NixosRebuildArgs(flakeDir, opts.Host, target, opts.BuildHost)
	fmt.Fprintf(out, "Running: nixos-rebuild %s\n", strings.Join(args, " "))
	cmd := nixosRebuild(ctx, flakeDir, args, "NIX_SSHOPTS="+sshOpts)
	cmd.Stdout, cmd.Stderr, cmd.Stdin = out, errOut, os.Stdin
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("nixos-rebuild failed: %w", err)
	}
	fmt.Fprintf(out, "%s is now running its neusis configuration; reach it over the tailnet.\n", opts.Host)
	return nil
}

// Deploy is day 2: nixos-rebuild switch to an already bootstrapped host.
func Deploy(ctx context.Context, flakeDir, host, target string, buildOnTarget bool, out, errOut io.Writer) error {
	abs, err := filepath.Abs(flakeDir)
	if err != nil {
		return err
	}
	if target == "" {
		target = "root@" + host
	}
	args := NixosRebuildArgs(abs, host, target, buildOnTarget)
	fmt.Fprintf(out, "Running: nixos-rebuild %s\n", strings.Join(args, " "))
	cmd := nixosRebuild(ctx, abs, args)
	cmd.Stdout, cmd.Stderr, cmd.Stdin = out, errOut, os.Stdin
	return cmd.Run()
}

// nixosRebuild builds the nixos-rebuild command. TMPDIR is forced to a
// short path: nixos-rebuild puts its ssh ControlPath socket under
// $TMPDIR, and inside `nix develop` (TMPDIR=/tmp/nix-shell.XXXXXX/…)
// that exceeds the Unix-socket path limit ("unix_listener: path … too
// long"), killing nix-copy-closure.
func nixosRebuild(ctx context.Context, dir string, args []string, extraEnv ...string) *exec.Cmd {
	cmd := exec.CommandContext(ctx, "nixos-rebuild", args...)
	cmd.Dir = dir
	cmd.Env = append(append(os.Environ(), "TMPDIR=/tmp"), extraEnv...)
	return cmd
}

func tofuOutput(ctx context.Context, flakeDir, stack string, errOut io.Writer) ([]byte, error) {
	// The stack wrapper (features/flake/_terranix-defaults.nix) must run
	// from the repo root and sources the operator's env file itself.
	cmd := exec.CommandContext(ctx, "nix", "run", flakeDir+"#"+stack+".terraform", "--", "output", "-json")
	cmd.Dir = flakeDir
	cmd.Stderr = errOut
	raw, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("tofu output for stack %s: %w", stack, err)
	}
	return raw, nil
}

func nixEvalRaw(ctx context.Context, flakeDir, attr string) (string, error) {
	cmd := exec.CommandContext(ctx, "nix", "eval", "--raw", flakeDir+"#"+attr)
	cmd.Dir = flakeDir
	raw, err := cmd.Output()
	if err != nil {
		if ee, ok := err.(*exec.ExitError); ok {
			return "", fmt.Errorf("nix eval %s: %s", attr, strings.TrimSpace(string(ee.Stderr)))
		}
		return "", fmt.Errorf("nix eval %s: %w", attr, err)
	}
	return strings.TrimSpace(string(raw)), nil
}

// firstContactOpts: the instance has a random host key until we replace it.
var firstContactOpts = []string{"-o", "UserKnownHostsFile=/dev/null", "-o", "StrictHostKeyChecking=no", "-o", "LogLevel=ERROR"}

func waitForSSH(ctx context.Context, target string, timeout time.Duration) error {
	deadline := time.Now().Add(timeout)
	for {
		err := sshRun(ctx, target, append(firstContactOpts, "-o", "ConnectTimeout=5"), "true", io.Discard)
		if err == nil {
			return nil
		}
		if time.Now().After(deadline) {
			return fmt.Errorf("ssh to %s did not come up within %s: %w", target, timeout, err)
		}
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-time.After(5 * time.Second):
		}
	}
}

func sshRun(ctx context.Context, target string, opts []string, remote string, errOut io.Writer) error {
	args := append([]string{"-o", "BatchMode=yes"}, opts...)
	args = append(args, target, remote)
	cmd := exec.CommandContext(ctx, "ssh", args...)
	cmd.Stderr = errOut
	return cmd.Run()
}

// pushTree streams the decrypted root tree into / on the target and
// restarts sshd. File modes were normalised by CreateRootStructure and
// travel with the stream; ownership must not: the stream's directory
// entries (".", "etc", …) carry the operator's uid and the temp dir's
// 0700 mode, and extracting them as root once turned the host's "/"
// into drwx------ UNKNOWN:wheel, breaking every non-root service. Hence
// --no-overwrite-dir (keep metadata of existing directories) and
// --no-same-owner (new files belong to root).
func pushTree(ctx context.Context, tree, target string, errOut io.Writer) error {
	tar := exec.CommandContext(ctx, "tar", "-C", tree, "-cf", "-", ".")
	ssh := exec.CommandContext(ctx, "ssh", append(append([]string{"-o", "BatchMode=yes"}, firstContactOpts...), target,
		"tar -C / --no-overwrite-dir --no-same-owner -xf - && systemctl restart sshd")...)
	pipe, err := tar.StdoutPipe()
	if err != nil {
		return err
	}
	ssh.Stdin = pipe
	ssh.Stderr = errOut
	tar.Stderr = errOut
	if err := tar.Start(); err != nil {
		return err
	}
	if err := ssh.Run(); err != nil {
		return fmt.Errorf("pushing bootstrap tree: %w", err)
	}
	return tar.Wait()
}

func writers(opts Options) (io.Writer, io.Writer) {
	out, errOut := opts.Out, opts.ErrOut
	if out == nil {
		out = os.Stdout
	}
	if errOut == nil {
		errOut = os.Stderr
	}
	return out, errOut
}

func keys(m map[string]map[string]string) []string {
	ks := make([]string, 0, len(m))
	for k := range m {
		ks = append(ks, k)
	}
	return ks
}
