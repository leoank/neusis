package cmd

import (
	"context"
	"os"

	"github.com/charmbracelet/fang"
	"github.com/spf13/cobra"
)

// version is overridden at build time via -ldflags.
var version = "dev"

func newRootCmd() *cobra.Command {
	root := &cobra.Command{
		Use:   "neusis",
		Short: "Scaffold and grow a neusis fleet configuration",
		Long: `neusis is a wizard-driven CLI for creating and maintaining a neusis
NixOS/nix-darwin fleet repository.

Run it with no arguments to be guided interactively, or pass flags to
script it in CI. It only reads and writes files; it never requires Nix
to be installed, though it will use nix and git when they are present.`,
		SilenceUsage:  true,
		SilenceErrors: true,
	}

	root.AddCommand(
		newInitCmd(),
		newAddCmd(),
		newVersionCmd(),
	)
	return root
}

// Execute runs the root command with fang's styled help/error handling.
func Execute() {
	if err := fang.Execute(
		context.Background(),
		newRootCmd(),
		fang.WithVersion(version),
	); err != nil {
		os.Exit(1)
	}
}
