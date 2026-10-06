// docgen walks the neusis cobra command tree and prints it as JSON on
// stdout. render.py turns that into the CLI reference pages.
package main

import (
	"encoding/json"
	"os"

	"github.com/leoank/neusis/cli/cmd"
	"github.com/spf13/cobra"
	"github.com/spf13/pflag"
)

type flag struct {
	Name      string `json:"name"`
	Shorthand string `json:"shorthand"`
	Type      string `json:"type"`
	Default   string `json:"default"`
	Usage     string `json:"usage"`
}

type command struct {
	Path      string    `json:"path"`
	Use       string    `json:"use"`
	Short     string    `json:"short"`
	Long      string    `json:"long"`
	Example   string    `json:"example"`
	Aliases   []string  `json:"aliases"`
	Runnable  bool      `json:"runnable"`
	Flags     []flag    `json:"flags"`
	Inherited []flag    `json:"inherited"`
	Commands  []command `json:"commands"`
}

func flags(fs *pflag.FlagSet) []flag {
	out := []flag{}
	fs.VisitAll(func(f *pflag.Flag) {
		if f.Hidden {
			return
		}
		out = append(out, flag{f.Name, f.Shorthand, f.Value.Type(), f.DefValue, f.Usage})
	})
	return out
}

func walk(c *cobra.Command) command {
	out := command{
		Path:      c.CommandPath(),
		Use:       c.UseLine(),
		Short:     c.Short,
		Long:      c.Long,
		Example:   c.Example,
		Aliases:   c.Aliases,
		Runnable:  c.Runnable(),
		Flags:     flags(c.NonInheritedFlags()),
		Inherited: flags(c.InheritedFlags()),
		Commands:  []command{},
	}
	for _, sub := range c.Commands() {
		if sub.IsAvailableCommand() {
			out.Commands = append(out.Commands, walk(sub))
		}
	}
	return out
}

func main() {
	root := cmd.DocsRoot()
	root.InitDefaultHelpFlag()
	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "  ")
	if err := enc.Encode(walk(root)); err != nil {
		os.Exit(1)
	}
}
