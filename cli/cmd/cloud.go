package cmd

import (
	"os"
	"path/filepath"
	"time"

	"github.com/leoank/neusis/cli/internal/cloud"
	"github.com/spf13/cobra"
)

func newCloudCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "cloud",
		Short: "Bootstrap and deploy neusis cloud machines (terranix stacks)",
		Long: `Cloud machines are provisioned by the terranix stacks (nix run .#<stack>.apply)
from a shared NixOS base image; these commands take them from there.

  bootstrap  push the host's pre-generated SSH host key, verify it, and
             nixos-rebuild switch the instance to its neusis configuration
  deploy     nixos-rebuild switch an already bootstrapped host (day 2)

Run from the repository root; both need nix, ssh and nixos-rebuild on PATH,
bootstrap additionally needs age and your master identity.`,
	}
	cmd.AddCommand(newCloudBootstrapCmd(), newCloudDeployCmd())
	return cmd
}

func newCloudBootstrapCmd() *cobra.Command {
	var opts cloud.Options
	var timeout time.Duration
	cmd := &cobra.Command{
		Use:   "bootstrap <host>",
		Short: "Turn a freshly provisioned instance into its neusis host",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			opts.Host = args[0]
			opts.Timeout = timeout
			opts.Out, opts.ErrOut = cmd.OutOrStdout(), cmd.ErrOrStderr()
			return cloud.Run(cmd.Context(), opts)
		},
	}
	cmd.Flags().StringVar(&opts.Stack, "stack", "oci-anklab", "terranix stack whose outputs hold the instance IP")
	cmd.Flags().StringVar(&opts.IP, "ip", "", "instance IP (skips the stack output lookup)")
	cmd.Flags().StringVar(&opts.FlakeDir, "flake", ".", "repository root (the flake)")
	cmd.Flags().StringVarP(&opts.KeyPath, "key", "k", defaultMasterIdentity(), "master identity that decrypts modules/secrets/bootstrap/<host>")
	cmd.Flags().StringVar(&opts.SSHUser, "ssh-user", "root", "user on the fresh instance")
	cmd.Flags().BoolVar(&opts.BuildHost, "build-on-target", false, "build the configuration on the instance instead of locally")
	cmd.Flags().DurationVar(&timeout, "timeout", 10*time.Minute, "how long to wait for SSH")
	return cmd
}

func newCloudDeployCmd() *cobra.Command {
	var flakeDir, target string
	var buildOnTarget bool
	cmd := &cobra.Command{
		Use:   "deploy <host>",
		Short: "nixos-rebuild switch a bootstrapped host over the tailnet",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			return cloud.Deploy(cmd.Context(), flakeDir, args[0], target, buildOnTarget, cmd.OutOrStdout(), cmd.ErrOrStderr())
		},
	}
	cmd.Flags().StringVar(&flakeDir, "flake", ".", "repository root (the flake)")
	cmd.Flags().StringVar(&target, "target", "", "ssh target (default root@<host>)")
	cmd.Flags().BoolVar(&buildOnTarget, "build-on-target", false, "build the configuration on the host instead of locally")
	return cmd
}

// defaultMasterIdentity is the operator's agenix master identity
// (the key the bootstrap trees are encrypted to).
func defaultMasterIdentity() string {
	home, err := os.UserHomeDir()
	if err != nil {
		return "~/.ssh/id_ed25519"
	}
	return filepath.Join(home, ".ssh", "id_ed25519")
}
