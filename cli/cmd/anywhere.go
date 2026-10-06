package cmd

import (
	"fmt"
	"path/filepath"

	"github.com/leoank/neusis/cli/internal/anywhere"
	"github.com/spf13/cobra"
)

func newAnywhereCmd() *cobra.Command {
	var (
		tempFolder string
		keyPath    string
	)

	cmd := &cobra.Command{
		Use:   "anywhere",
		Short: "Bootstrap NixOS machines with nixos-anywhere and agenix secrets",
		Long: `Deploy NixOS systems using nixos-anywhere with decrypted age secrets,
or prepare decrypted extra files locally for inspection.

Features:
  - Decrypts .age files using age with your host or user SSH private key
  - Retains destination directory hierarchy and removes .age extensions
  - Enforces correct permissions on SSH host keys (600 private, 644 public)
  - Forwards configuration to nixos-anywhere with --extra-files and -t`,
		Args: cobra.ArbitraryArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			if len(args) == 0 {
				return cmd.Help()
			}
			// Backward compatibility: running `neusis anywhere <extra_files_folder>` runs decrypt.
			if len(args) == 1 {
				absExtra, err := filepath.Abs(args[0])
				if err != nil {
					return err
				}
				absTemp, err := filepath.Abs(tempFolder)
				if err != nil {
					return err
				}
				absKey, err := filepath.Abs(keyPath)
				if err != nil {
					return err
				}
				return anywhere.CreateRootStructure(cmd.Context(), anywhere.DecryptOptions{
					ExtraFilesFolder: absExtra,
					TempFolder:       absTemp,
					KeyPath:          absKey,
					Out:              cmd.OutOrStdout(),
					ErrOut:           cmd.ErrOrStderr(),
				})
			}
			return cmd.Help()
		},
	}

	cmd.PersistentFlags().StringVar(&tempFolder, "temp-folder", anywhere.DefaultTempFolder, "Temporary folder to assemble root structure")
	cmd.PersistentFlags().StringVarP(&keyPath, "key", "k", anywhere.DefaultDecryptionKeyPath, "Path to SSH private key for age decryption")

	cmd.AddCommand(
		newAnywhereDeployCmd(&tempFolder, &keyPath),
		newAnywhereDecryptCmd(&tempFolder, &keyPath),
	)

	return cmd
}

func newAnywhereDeployCmd(tempFolder, keyPath *string) *cobra.Command {
	var (
		flake                     string
		extraFiles                string
		sshPort                   int
		identityFile              string
		copyHostKeys              bool
		printBuildLogs            bool
		debug                     bool
		vmTest                    bool
		buildOnRemote             bool
		noSubstituteOnDestination bool
		kexec                     string
		extraArgs                 []string
	)

	cmd := &cobra.Command{
		Use:   "deploy <target-host> [extra-files-folder]",
		Short: "Deploy using nixos-anywhere with decrypted extra files",
		Long: `Deploy a NixOS machine using nixos-anywhere with decrypted age secrets.

The target host is passed as the first positional argument. The folder
containing .age files can be passed as the second positional argument or
via --extra-files.`,
		Args: cobra.RangeArgs(1, 2),
		RunE: func(cmd *cobra.Command, args []string) error {
			targetHost := args[0]
			extraFolder := extraFiles
			if len(args) == 2 {
				extraFolder = args[1]
			}
			if extraFolder == "" {
				return fmt.Errorf("extra-files folder must be provided either as 2nd positional argument or via --extra-files")
			}

			absExtra, err := filepath.Abs(extraFolder)
			if err != nil {
				return err
			}
			absTemp, err := filepath.Abs(*tempFolder)
			if err != nil {
				return err
			}
			absKey, err := filepath.Abs(*keyPath)
			if err != nil {
				return err
			}

			opts := anywhere.DeployOptions{
				DecryptOptions: anywhere.DecryptOptions{
					ExtraFilesFolder: absExtra,
					TempFolder:       absTemp,
					KeyPath:          absKey,
					Out:              cmd.OutOrStdout(),
					ErrOut:           cmd.ErrOrStderr(),
				},
				TargetHost:                targetHost,
				Flake:                     flake,
				SSHPort:                   sshPort,
				IdentityFile:              identityFile,
				CopyHostKeys:              copyHostKeys,
				PrintBuildLogs:            printBuildLogs,
				Debug:                     debug,
				VMTest:                    vmTest,
				BuildOnRemote:             buildOnRemote,
				NoSubstituteOnDestination: noSubstituteOnDestination,
				Kexec:                     kexec,
				ExtraArgs:                 extraArgs,
				Stdin:                     cmd.InOrStdin(),
				Stdout:                    cmd.OutOrStdout(),
				Stderr:                    cmd.ErrOrStderr(),
			}

			return anywhere.RunNixosAnywhere(cmd.Context(), opts)
		},
	}

	cmd.Flags().StringVarP(&flake, "flake", "f", "", "Flake URI (e.g. .#machine-name) (required)")
	_ = cmd.MarkFlagRequired("flake")
	cmd.Flags().StringVar(&extraFiles, "extra-files", "", "Path to folder containing .age files (can also be passed as 2nd positional argument)")
	cmd.Flags().IntVarP(&sshPort, "ssh-port", "p", 0, "SSH port")
	cmd.Flags().StringVarP(&identityFile, "identity-file", "i", "", "SSH private key file for target host connection")
	cmd.Flags().BoolVar(&copyHostKeys, "copy-host-keys", false, "Copy existing host keys")
	cmd.Flags().BoolVarP(&printBuildLogs, "print-build-logs", "L", false, "Print full build logs")
	cmd.Flags().BoolVar(&debug, "debug", false, "Enable debug output")
	cmd.Flags().BoolVar(&vmTest, "vm-test", false, "Test in VM without installing")
	cmd.Flags().BoolVar(&buildOnRemote, "build-on-remote", false, "Build on remote machine")
	cmd.Flags().BoolVar(&noSubstituteOnDestination, "no-substitute-on-destination", false, "Disable substitute on destination")
	cmd.Flags().StringVar(&kexec, "kexec", "", "Use another kexec tarball to bootstrap NixOS")
	cmd.Flags().StringSliceVar(&extraArgs, "extra-args", nil, "Additional arguments to pass to nixos-anywhere")

	return cmd
}

func newAnywhereDecryptCmd(tempFolder, keyPath *string) *cobra.Command {
	return &cobra.Command{
		Use:   "decrypt <extra-files-folder>",
		Short: "Only decrypt files and create root structure",
		Long: `Decrypt age files from the specified folder and assemble the destination
root structure into the temporary directory without executing nixos-anywhere.`,
		Args: cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			absExtra, err := filepath.Abs(args[0])
			if err != nil {
				return err
			}
			absTemp, err := filepath.Abs(*tempFolder)
			if err != nil {
				return err
			}
			absKey, err := filepath.Abs(*keyPath)
			if err != nil {
				return err
			}

			return anywhere.CreateRootStructure(cmd.Context(), anywhere.DecryptOptions{
				ExtraFilesFolder: absExtra,
				TempFolder:       absTemp,
				KeyPath:          absKey,
				Out:              cmd.OutOrStdout(),
				ErrOut:           cmd.ErrOrStderr(),
			})
		},
	}
}
