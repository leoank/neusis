package cmd

import (
	"context"
	"fmt"
	"time"

	"github.com/leoank/neusis/cli/internal/schema"
	"github.com/leoank/neusis/cli/internal/source"
	"github.com/leoank/neusis/cli/internal/tmpl"
	"github.com/spf13/cobra"
)

// allSpecs is the full set of refreshable files: every template plus the
// schema snapshot.
func allSpecs() []source.Spec {
	return append(tmpl.Specs(), schema.Spec())
}

func newUpdateCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "update",
		Short: "Refresh templates and schema from the neusis repo",
		Long: `Fetch the latest scaffolding templates and option-schema snapshot
from the neusis repo into the local cache. The CLI prefers these over
its built-in copies, so this picks up template changes without a new
release. Set NEUSIS_REF to pull from a branch/tag other than main.`,
		Args: cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			if source.Offline() {
				return fmt.Errorf("NEUSIS_OFFLINE is set; unset it to refresh")
			}
			repo, ref := source.Location()
			out := cmd.OutOrStdout()
			fmt.Fprintf(out, "Refreshing from %s@%s…\n", repo, ref)

			ctx, cancel := context.WithTimeout(cmd.Context(), 30*time.Second)
			defer cancel()
			n, err := source.Refresh(ctx, allSpecs())
			if err != nil {
				return err
			}
			if n == 0 {
				fmt.Fprintln(out, "No files fetched (nothing reachable at that ref). Using built-in copies.")
			} else {
				fmt.Fprintf(out, "Cached %d file(s).\n", n)
			}
			return nil
		},
	}
}
