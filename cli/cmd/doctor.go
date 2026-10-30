package cmd

import (
	"fmt"

	"github.com/leoank/neusis/cli/internal/doctor"
	"github.com/spf13/cobra"
)

func newDoctorCmd() *cobra.Command {
	var (
		targetDir string
		strict    bool
		jsonOut   bool
		noColor   bool
	)

	cmd := &cobra.Command{
		Use:   "doctor [dir]",
		Short: "Check the health and conventions of a neusis fleet repository",
		Long: `Inspect a neusis fleet repository for health, convention drift, and common
misconfigurations.

Doctor checks:
- Flake & Git hygiene (flake.nix, modules/, flake.lock, untracked .nix files).
- Machines and registry enrollment (catches machines not in nixos/darwin configurations).
- Darwin flake inputs for Darwin machines.
- Users and registry enrollment, plus presence of declared SSH key files.
- Registry completeness (machines, users, and builders seeding).
- Platform guards in agnosticModules (systemd/launchd cross-platform safety).
- Secrets infrastructure and agenix-rekey master identity setup.`,
		Args: cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			start := "."
			if len(args) > 0 {
				start = args[0]
			} else if targetDir != "" {
				start = targetDir
			}

			// If no explicit dir was passed, look for enclosing repo root
			var root string
			if len(args) == 0 && targetDir == "" {
				if found, err := findRepoRoot(start); err == nil {
					root = found
				} else {
					root = start
				}
			} else {
				root = start
			}

			report, err := doctor.Diagnose(root)
			if err != nil {
				return fmt.Errorf("failed to diagnose repository: %w", err)
			}

			out := cmd.OutOrStdout()
			if jsonOut {
				if err := report.RenderJSON(out); err != nil {
					return err
				}
			} else {
				report.RenderText(out, noColor)
			}

			if !report.OK() {
				return fmt.Errorf("doctor check failed: %d failure(s) found", report.FailCount)
			}
			if strict && !report.StrictOK() {
				return fmt.Errorf("doctor check failed (strict mode): %d warning(s) found", report.WarnCount)
			}

			return nil
		},
	}

	cmd.Flags().StringVarP(&targetDir, "dir", "C", "", "Target repository directory (defaults to current directory or enclosing fleet repo)")
	cmd.Flags().BoolVar(&strict, "strict", false, "Fail if any warnings are detected")
	cmd.Flags().BoolVar(&jsonOut, "json", false, "Output report as JSON")
	cmd.Flags().BoolVar(&noColor, "no-color", false, "Disable colored output")

	return cmd
}
