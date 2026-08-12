package cmd

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/charmbracelet/huh"
	"github.com/leoank/neusis/cli/internal/gen"
	"github.com/leoank/neusis/cli/internal/nix"
	"github.com/leoank/neusis/cli/internal/scaffold"
	"github.com/leoank/neusis/cli/internal/tmpl"
	"github.com/leoank/neusis/cli/internal/wizard"
	"github.com/spf13/cobra"
)

func newAddCmd() *cobra.Command {
	add := &cobra.Command{
		Use:   "add",
		Short: "Add a machine, user, or registry to the current repository",
	}
	add.AddCommand(newAddMachineCmd(), newAddUserCmd(), newAddRegistryCmd())
	return add
}

// openRepo finds the enclosing repo and returns a writer rooted there.
func openRepo(force bool) (*scaffold.Writer, string, error) {
	cwd, err := os.Getwd()
	if err != nil {
		return nil, "", err
	}
	root, err := findRepoRoot(cwd)
	if err != nil {
		return nil, "", err
	}
	w := scaffold.New(root)
	w.Force = force
	return w, root, nil
}

func finish(cmd *cobra.Command, w *scaffold.Writer, root string) {
	out := cmd.OutOrStdout()
	reportWritten(out, w)
	if nix.IsRepo(root) {
		_ = nix.GitAdd(cmd.Context(), root, w.Written()...)
	}
}

// ---- add machine ----

func newAddMachineCmd() *cobra.Command {
	var (
		system      string
		hostname    string
		pubkey      string
		primaryUser string
		lab         string
		force       bool
		yes         bool
	)
	cmd := &cobra.Command{
		Use:   "machine [name]",
		Short: "Add a host to the fleet",
		Args:  cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			w, root, err := openRepo(force)
			if err != nil {
				return err
			}
			m := tmpl.Machine{
				System:       system,
				HostPubkey:   pubkey,
				PrimaryUser:  primaryUser,
				Lab:          lab,
				StateVersion: wizard.DefaultStateVersion,
			}
			if len(args) == 1 {
				m.Name = args[0]
				m.Hostname = args[0]
			}
			if m.Lab == "" {
				m.Lab = wizard.DefaultLab
			}
			if !yes && isTTY() {
				if err := runMachineForm(&m); err != nil {
					return err
				}
			}
			normalizeMachine(&m)
			if err := validateMachine(m); err != nil {
				return err
			}
			if err := gen.Machine(w, m); err != nil {
				return err
			}
			fmt.Fprintf(cmd.OutOrStdout(), "Added machine %q to lab %q:\n", m.Name, m.Lab)
			finish(cmd, w, root)
			return nil
		},
	}
	f := cmd.Flags()
	f.StringVar(&system, "system", "", "target system (e.g. x86_64-linux, aarch64-darwin)")
	f.StringVar(&hostname, "hostname", "", "hostname (default: name)")
	f.StringVar(&pubkey, "host-pubkey", "", "SSH host public key")
	f.StringVar(&primaryUser, "primary-user", "", "primary user (darwin)")
	f.StringVar(&lab, "lab", "", "registry lab to join (default: home)")
	f.BoolVar(&force, "force", false, "overwrite an existing file")
	f.BoolVar(&yes, "yes", false, "non-interactive: use flags and defaults")
	return cmd
}

func runMachineForm(m *tmpl.Machine) error {
	if m.System == "" {
		m.System = wizard.Systems[0].System
	}
	sysOpts := make([]huh.Option[string], 0, len(wizard.Systems))
	for _, s := range wizard.Systems {
		sysOpts = append(sysOpts, huh.NewOption(s.Label, s.System))
	}
	form := huh.NewForm(
		huh.NewGroup(
			huh.NewInput().
				Title("Machine name").
				Description("Attribute key and hostname (e.g. oppy).").
				Value(&m.Name).
				Validate(wizard.ValidateIdent),
			huh.NewSelect[string]().
				Title("System").
				Description("Target architecture. Sets nixpkgs.hostPlatform and picks the builder (NixOS vs nix-darwin).").
				Options(sysOpts...).
				Value(&m.System),
			huh.NewInput().
				Title("SSH host public key").
				Description("Used by agenix-rekey to encrypt per-host secrets. Leave blank to fill in later.").
				Value(&m.HostPubkey),
			huh.NewInput().
				Title("Primary user").
				Description("On Darwin, wired to system.primaryUser (homebrew, activation). Optional.").
				Value(&m.PrimaryUser),
		),
	)
	return form.Run()
}

func normalizeMachine(m *tmpl.Machine) {
	if m.Hostname == "" {
		m.Hostname = m.Name
	}
	m.Platform = wizard.PlatformOf(m.System)
	if m.HostPubkey == "" {
		m.HostPubkey = "REPLACE-ME ssh-ed25519 AAAA..."
	}
}

func validateMachine(m tmpl.Machine) error {
	if err := wizard.ValidateIdent(m.Name); err != nil {
		return fmt.Errorf("machine name: %w", err)
	}
	if m.System == "" {
		return fmt.Errorf("system is required (use --system)")
	}
	return nil
}

// ---- add user ----

func newAddUserCmd() *cobra.Command {
	var (
		fullName string
		shell    string
		role     string
		lab      string
		keyPath  string
		force    bool
		yes      bool
	)
	cmd := &cobra.Command{
		Use:   "user [name]",
		Short: "Add a person to the fleet",
		Args:  cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			w, root, err := openRepo(force)
			if err != nil {
				return err
			}
			u := tmpl.User{
				FullName: fullName,
				Shell:    shell,
				Role:     role,
				Lab:      lab,
			}
			if len(args) == 1 {
				u.Name = args[0]
				u.Username = args[0]
			}
			if u.Shell == "" {
				u.Shell = "zsh"
			}
			if u.Role == "" {
				u.Role = "admin"
			}
			if u.Lab == "" {
				u.Lab = wizard.DefaultLab
			}
			interactive := !yes && isTTY()
			if interactive {
				if err := runUserForm(w, &u); err != nil {
					return err
				}
			} else if keyPath != "" {
				if err := copyUserKey(w, &u, keyPath); err != nil {
					return err
				}
			}
			normalizeUser(&u)
			if err := wizard.ValidateIdent(u.Name); err != nil {
				return fmt.Errorf("user name: %w", err)
			}
			if err := gen.User(w, u); err != nil {
				return err
			}
			fmt.Fprintf(cmd.OutOrStdout(), "Added user %q (%s) to lab %q:\n", u.Name, u.Role, u.Lab)
			finish(cmd, w, root)
			return nil
		},
	}
	f := cmd.Flags()
	f.StringVar(&fullName, "full-name", "", "human-readable full name")
	f.StringVar(&shell, "shell", "", "login shell (default: zsh)")
	f.StringVar(&role, "role", "", "admin|regular|guest|locked (default: admin)")
	f.StringVar(&lab, "lab", "", "registry lab to join (default: home)")
	f.StringVar(&keyPath, "ssh-key", "", "path to a public SSH key to copy in")
	f.BoolVar(&force, "force", false, "overwrite an existing file")
	f.BoolVar(&yes, "yes", false, "non-interactive: use flags and defaults")
	return cmd
}

func runUserForm(w *scaffold.Writer, u *tmpl.User) error {
	roleOpts := make([]huh.Option[string], 0, len(wizard.Roles))
	for _, r := range wizard.Roles {
		roleOpts = append(roleOpts, huh.NewOption(r.Role+" — "+r.Help, r.Role))
	}
	var keyPath string
	form := huh.NewForm(
		huh.NewGroup(
			huh.NewInput().
				Title("Username").
				Description("System username and attribute key.").
				Value(&u.Name).
				Validate(wizard.ValidateIdent),
			huh.NewInput().
				Title("Full name").
				Value(&u.FullName),
			huh.NewInput().
				Title("Login shell").
				Description("e.g. bash, zsh, fish.").
				Value(&u.Shell),
			huh.NewSelect[string]().
				Title("Role").
				Description("Determines privileges and which registry list the user joins.").
				Options(roleOpts...).
				Value(&u.Role),
			huh.NewInput().
				Title("Public SSH key path").
				Description("Optional. Copied into modules/users/keys/. Leave blank to add later.").
				Value(&keyPath),
		),
	)
	if err := form.Run(); err != nil {
		return err
	}
	if keyPath != "" {
		return copyUserKey(w, u, keyPath)
	}
	return nil
}

func copyUserKey(w *scaffold.Writer, u *tmpl.User, keyPath string) error {
	data, err := os.ReadFile(keyPath)
	if err != nil {
		return fmt.Errorf("read ssh key: %w", err)
	}
	name := u.Name
	if name == "" {
		name = "user"
	}
	rel := filepath.Join("modules", "users", "keys", name+".pub")
	if err := w.WriteFile(rel, data); err != nil {
		return err
	}
	u.KeyFile = "./keys/" + name + ".pub"
	return nil
}

func normalizeUser(u *tmpl.User) {
	if u.Username == "" {
		u.Username = u.Name
	}
	if u.FullName == "" {
		u.FullName = u.Name
	}
}

// ---- add registry ----

func newAddRegistryCmd() *cobra.Command {
	var force bool
	cmd := &cobra.Command{
		Use:     "registry [name]",
		Aliases: []string{"lab"},
		Short:   "Add a registry lab (grouping of machines and users)",
		Args:    cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			w, root, err := openRepo(force)
			if err != nil {
				return err
			}
			lab := tmpl.Lab{}
			if len(args) == 1 {
				lab.Name = args[0]
			}
			if lab.Name == "" && isTTY() {
				form := huh.NewForm(huh.NewGroup(
					huh.NewInput().
						Title("Lab name").
						Description("A grouping of machines and users (e.g. home, work).").
						Value(&lab.Name).
						Validate(wizard.ValidateIdent),
				))
				if err := form.Run(); err != nil {
					return err
				}
			}
			if err := wizard.ValidateIdent(lab.Name); err != nil {
				return fmt.Errorf("lab name: %w", err)
			}
			if err := gen.Lab(w, lab); err != nil {
				return err
			}
			fmt.Fprintf(cmd.OutOrStdout(), "Added registry lab %q:\n", lab.Name)
			finish(cmd, w, root)
			return nil
		},
	}
	cmd.Flags().BoolVar(&force, "force", false, "overwrite an existing file")
	return cmd
}
