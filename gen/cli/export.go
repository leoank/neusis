// Dropped into the neusis CLI's `cmd` package at docs build time so the
// docgen program can reach the (unexported) command tree.
package cmd

import "github.com/spf13/cobra"

// DocsRoot returns the full neusis command tree.
func DocsRoot() *cobra.Command { return newRootCmd() }
