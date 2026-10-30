package cmd

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/charmbracelet/huh"
	"github.com/leoank/neusis/cli/internal/gen"
	"github.com/leoank/neusis/cli/internal/nix"
	"github.com/leoank/neusis/cli/internal/scaffold"
	"github.com/leoank/neusis/cli/internal/schema"
	"github.com/leoank/neusis/cli/internal/source"
	"github.com/leoank/neusis/cli/internal/tmpl"
	"github.com/leoank/neusis/cli/internal/wizard"
	"github.com/spf13/cobra"
)

func newAddCmd() *cobra.Command {
	add := &cobra.Command{
		Use:   "add",
		Short: "Add a machine, user, registry, module, package, or feature to the current repository",
	}
	add.AddCommand(
		newAddMachineCmd(),
		newAddUserCmd(),
		newAddRegistryCmd(),
		newAddModuleCmd(),
		newAddPackageCmd(),
		newAddFeatureCmd(),
		newAddSecretsCmd(),
	)
	return add
}

// openRepo finds the enclosing repo and returns a writer rooted there.
// It also kicks off a best-effort, TTL-gated refresh of templates/schema
// from the neusis repo so `add` uses the latest copies when online.
func openRepo(force bool) (*scaffold.Writer, string, error) {
	source.MaybeRefresh(allSpecs())
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
				Secrets:      secretsEnabled(root),
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
			fmt.Fprintf(cmd.OutOrStdout(), "Added machine %q to machine registry %q:\n", m.Name, m.Lab)
			finish(cmd, w, root)
			if m.IsDarwin() && !hasDarwinInput(root) {
				warnMissingDarwinInput(cmd, root)
			}
			return nil
		},
	}
	f := cmd.Flags()
	f.StringVar(&system, "system", "", "target system (e.g. x86_64-linux, aarch64-darwin)")
	f.StringVar(&hostname, "hostname", "", "hostname (default: name)")
	f.StringVar(&pubkey, "host-pubkey", "", "SSH host public key")
	f.StringVar(&primaryUser, "primary-user", "", "primary user (darwin)")
	f.StringVar(&lab, "registry", "", "machine registry to join (default: home)")
	f.StringVar(&lab, "lab", "", "alias for --registry")
	f.BoolVar(&force, "force", false, "overwrite an existing file")
	f.BoolVar(&yes, "yes", false, "non-interactive: use flags and defaults")
	return cmd
}

// warnMissingDarwinInput tells the user a nix-darwin host won't build
// until the repo declares a `darwin` flake input, with the exact fix
// for its flake style.
func warnMissingDarwinInput(cmd *cobra.Command, root string) {
	err := cmd.ErrOrStderr()
	block := `    darwin = {
      url = "` + wizard.DefaultDarwinRef + `";
      inputs.nixpkgs.follows = "nixpkgs";
    };`
	fmt.Fprintln(err, "\nwarning: this repo has no `darwin` flake input; this host won't build until you add one.")
	if isDendritic(root) {
		fmt.Fprintln(err, "Add it to modules/dendritic.nix under `flake-file.inputs`:")
		fmt.Fprintln(err, block)
		fmt.Fprintln(err, "then: git add . && nix run .#write-flake && nix flake lock")
	} else {
		fmt.Fprintln(err, "Add it to flake.nix under `inputs`:")
		fmt.Fprintln(err, block)
		fmt.Fprintln(err, "then: nix flake lock")
	}
}

func runMachineForm(m *tmpl.Machine) error {
	if m.System == "" {
		m.System = wizard.Systems[0].System
	}
	if m.Lab == "" {
		m.Lab = wizard.DefaultRegistry
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
				Description(schema.HelpOr("machine", "system", "Target architecture. Sets nixpkgs.hostPlatform and picks the builder (NixOS vs nix-darwin).")).
				Options(sysOpts...).
				Value(&m.System),
			huh.NewInput().
				Title("Machine registry").
				Description("Machine registry this host joins (e.g. home, work).").
				Value(&m.Lab).
				Validate(wizard.ValidateIdent),
			huh.NewInput().
				Title("SSH host public key").
				Description(schema.HelpOr("machine", "hostPubkey", "Used by agenix-rekey to encrypt per-host secrets. Leave blank to fill in later.")).
				Value(&m.HostPubkey),
			huh.NewInput().
				Title("Primary user").
				Description(schema.HelpOr("machine", "primaryUser", "On Darwin, wired to system.primaryUser (homebrew, activation). Optional.")).
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
			fmt.Fprintf(cmd.OutOrStdout(), "Added user %q (%s) to user registry %q:\n", u.Name, u.Role, u.Lab)
			finish(cmd, w, root)
			return nil
		},
	}
	f := cmd.Flags()
	f.StringVar(&fullName, "full-name", "", "human-readable full name")
	f.StringVar(&shell, "shell", "", "login shell (default: zsh)")
	f.StringVar(&role, "role", "", "admin|regular|guest|locked (default: admin)")
	f.StringVar(&lab, "registry", "", "user registry to join (default: home)")
	f.StringVar(&lab, "lab", "", "alias for --registry")
	f.StringVar(&keyPath, "ssh-key", "", "path to a public SSH key to copy in")
	f.BoolVar(&force, "force", false, "overwrite an existing file")
	f.BoolVar(&yes, "yes", false, "non-interactive: use flags and defaults")
	return cmd
}

func runUserForm(w *scaffold.Writer, u *tmpl.User) error {
	if u.Lab == "" {
		u.Lab = wizard.DefaultRegistry
	}
	roleOpts := make([]huh.Option[string], 0, len(wizard.Roles))
	for _, r := range wizard.Roles {
		roleOpts = append(roleOpts, huh.NewOption(r.Role+" — "+r.Help, r.Role))
	}
	var keyPath string
	form := huh.NewForm(
		huh.NewGroup(
			huh.NewInput().
				Title("Username").
				Description(schema.HelpOr("user", "username", "System username and attribute key.")).
				Value(&u.Name).
				Validate(wizard.ValidateIdent),
			huh.NewInput().
				Title("Full name").
				Description(schema.HelpOr("user", "fullName", "Human-readable full name.")).
				Value(&u.FullName),
			huh.NewInput().
				Title("Login shell").
				Description(schema.HelpOr("user", "shell", "e.g. bash, zsh, fish.")).
				Value(&u.Shell),
			huh.NewSelect[string]().
				Title("Role").
				Description("Determines privileges and which registry list the user joins.").
				Options(roleOpts...).
				Value(&u.Role),
			huh.NewInput().
				Title("User registry").
				Description("User registry this person joins (e.g. home, work).").
				Value(&u.Lab).
				Validate(wizard.ValidateIdent),
			huh.NewInput().
				Title("Public SSH key path").
				Description(schema.HelpOr("user", "sshKeys", "Public SSH key files authorized for this user.")+" Copied into modules/users/keys/; blank to add later.").
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
	var (
		force bool
		yes   bool
	)
	cmd := &cobra.Command{
		Use:     "registry [name]",
		Aliases: []string{"lab"},
		Short:   "Add a registry (machine, user, and builders registries)",
		Args:    cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			w, root, err := openRepo(force)
			if err != nil {
				return err
			}
			reg := tmpl.Registry{}
			if len(args) == 1 {
				reg.Name = args[0]
			}
			if reg.Name == "" && !yes && isTTY() {
				form := huh.NewForm(huh.NewGroup(
					huh.NewInput().
						Title("Registry name").
						Description("Creates machine, user, and builders registries under modules/registry/ (e.g. home, work).").
						Value(&reg.Name).
						Validate(wizard.ValidateIdent),
				))
				if err := form.Run(); err != nil {
					return err
				}
			}
			if err := wizard.ValidateIdent(reg.Name); err != nil {
				return fmt.Errorf("registry name: %w", err)
			}
			if err := gen.Registry(w, reg); err != nil {
				return err
			}
			fmt.Fprintf(cmd.OutOrStdout(), "Added registry %q (machine, user, builders):\n", reg.Name)
			finish(cmd, w, root)
			return nil
		},
	}
	cmd.Flags().BoolVar(&force, "force", false, "overwrite an existing file")
	cmd.Flags().BoolVar(&yes, "yes", false, "non-interactive: use flags and defaults")
	return cmd
}

// ---- add secrets ----

func newAddSecretsCmd() *cobra.Command {
	var (
		masterID  string
		masterPub string
		force     bool
		yes       bool
	)
	cmd := &cobra.Command{
		Use:   "secrets [name]",
		Short: "Set up agenix-rekey secrets, or scaffold a named secret",
		Long: `Ensure the repo's agenix-rekey secrets infrastructure exists
(secrets/ tree + master identity), then, if a secret name is given,
print the operator workflow to create and wire it.

The first run bootstraps: it records your master identity and, going
forward, machines added with 'neusis add machine' are wired to it.`,
		Args: cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			w, root, err := openRepo(force)
			if err != nil {
				return err
			}
			out := cmd.OutOrStdout()

			if !secretsEnabled(root) {
				id := tmpl.MasterIdentity{IdentityPath: masterID, Pubkey: masterPub}
				if !yes && isTTY() {
					if err := runMasterIdentityForm(&id); err != nil {
						return err
					}
				}
				if id.IdentityPath == "" || id.Pubkey == "" {
					return fmt.Errorf("no secrets infrastructure yet; provide --master-identity and --master-pubkey (or run interactively)")
				}
				if err := gen.MasterIdentities(w, id); err != nil {
					return err
				}
				fmt.Fprintln(out, "Bootstrapped secrets infrastructure:")
				finish(cmd, w, root)
				fmt.Fprintln(out, "\nMachines added from now on will be wired to this identity.")
				fmt.Fprintln(out, "Re-run `neusis add machine` for existing hosts, or add the")
				fmt.Fprintln(out, "neusis.services.secrets block to them by hand.")
			} else {
				fmt.Fprintln(out, "Secrets infrastructure already present (secrets/master-identities.nix).")
			}

			if len(args) == 1 {
				printSecretWorkflow(cmd, args[0])
			}
			return nil
		},
	}
	f := cmd.Flags()
	f.StringVar(&masterID, "master-identity", "", "path to your agenix-rekey master private key")
	f.StringVar(&masterPub, "master-pubkey", "", "public key matching --master-identity")
	f.BoolVar(&force, "force", false, "overwrite existing files")
	f.BoolVar(&yes, "yes", false, "non-interactive: use flags, skip prompts")
	return cmd
}

// printSecretWorkflow explains how to create and wire one named secret.
// Per-machine `age.secrets.<name>` wiring is a system-level option that
// lives inside a host's module, so the CLI points at the operator steps
// rather than editing machine files.
func printSecretWorkflow(cmd *cobra.Command, name string) {
	out := cmd.OutOrStdout()
	fmt.Fprintf(out, "\nTo add the secret %q:\n", name)
	fmt.Fprintf(out, "  1. Create + encrypt it:   agenix edit secrets/common/%s.age\n", name)
	fmt.Fprintf(out, "  2. Wire it into a host's module (modules/machines/<host>.nix):\n")
	fmt.Fprintf(out, "       age.secrets.%s.rekeyFile = ../../secrets/common/%s.age;\n", name, name)
	fmt.Fprintln(out, "  3. Rekey for every host:  agenix rekey")
	fmt.Fprintln(out, "  4. git add secrets/ && commit")
}

// ---- add module ----

func newAddModuleCmd() *cobra.Command {
	var (
		modType     string
		description string
		force       bool
		yes         bool
	)
	cmd := &cobra.Command{
		Use:   "module [name]",
		Short: "Add a reusable module (agnostic, home, nixos, darwin)",
		Args:  cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			w, root, err := openRepo(force)
			if err != nil {
				return err
			}
			m := tmpl.Module{
				Type:        modType,
				Description: description,
			}
			if len(args) == 1 {
				m.Name = args[0]
			}
			if m.Type == "" {
				m.Type = "agnostic"
			}
			interactive := !yes && isTTY()
			if interactive {
				if err := runModuleForm(&m); err != nil {
					return err
				}
			}
			m.Type = normalizeModuleType(m.Type)
			if err := validateModule(m); err != nil {
				return err
			}
			if err := gen.Module(w, m); err != nil {
				return err
			}
			fmt.Fprintf(cmd.OutOrStdout(), "Added %s module %q:\n", m.Type, m.Name)
			finish(cmd, w, root)
			return nil
		},
	}
	f := cmd.Flags()
	f.StringVarP(&modType, "type", "t", "agnostic", "module type: agnostic, home, nixos, darwin")
	f.StringVar(&modType, "kind", "agnostic", "alias for --type")
	f.StringVarP(&description, "description", "d", "", "description for options documentation")
	f.BoolVar(&force, "force", false, "overwrite an existing file")
	f.BoolVar(&yes, "yes", false, "non-interactive: use flags and defaults")
	return cmd
}

func runModuleForm(m *tmpl.Module) error {
	typeOpts := []huh.Option[string]{
		huh.NewOption("agnostic — Cross-platform system module (NixOS + Darwin)", "agnostic"),
		huh.NewOption("home — Home-manager module (user configuration)", "home"),
		huh.NewOption("nixos — NixOS-only system module", "nixos"),
		huh.NewOption("darwin — nix-darwin-only system module", "darwin"),
	}
	form := huh.NewForm(
		huh.NewGroup(
			huh.NewInput().
				Title("Module name").
				Description("Attribute name for the module (e.g. wireguard, backup).").
				Value(&m.Name).
				Validate(wizard.ValidateIdent),
			huh.NewSelect[string]().
				Title("Module type").
				Description("Scope and platform target for this module.").
				Options(typeOpts...).
				Value(&m.Type),
			huh.NewInput().
				Title("Description").
				Description("Short summary for option documentation (optional).").
				Value(&m.Description),
		),
	)
	return form.Run()
}

func normalizeModuleType(t string) string {
	switch strings.ToLower(strings.TrimSpace(t)) {
	case "hm", "home", "homemanager", "home-manager":
		return "home"
	case "nixos":
		return "nixos"
	case "darwin", "nix-darwin":
		return "darwin"
	default:
		return "agnostic"
	}
}

func validateModule(m tmpl.Module) error {
	if err := wizard.ValidateIdent(m.Name); err != nil {
		return fmt.Errorf("module name: %w", err)
	}
	switch m.Type {
	case "agnostic", "home", "nixos", "darwin":
		return nil
	default:
		return fmt.Errorf("invalid module type %q; must be agnostic, home, nixos, or darwin", m.Type)
	}
}

// ---- add package ----

func newAddPackageCmd() *cobra.Command {
	var (
		description string
		force       bool
		yes         bool
	)
	cmd := &cobra.Command{
		Use:   "package [name]",
		Short: "Add a flake package",
		Args:  cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			w, root, err := openRepo(force)
			if err != nil {
				return err
			}
			p := tmpl.Package{
				Description: description,
			}
			if len(args) == 1 {
				p.Name = args[0]
			}
			interactive := !yes && isTTY()
			if interactive {
				if err := runPackageForm(&p); err != nil {
					return err
				}
			}
			if err := wizard.ValidateIdent(p.Name); err != nil {
				return fmt.Errorf("package name: %w", err)
			}
			if err := gen.Package(w, p); err != nil {
				return err
			}
			fmt.Fprintf(cmd.OutOrStdout(), "Added package %q:\n", p.Name)
			finish(cmd, w, root)
			return nil
		},
	}
	f := cmd.Flags()
	f.StringVarP(&description, "description", "d", "", "package description")
	f.BoolVar(&force, "force", false, "overwrite an existing file")
	f.BoolVar(&yes, "yes", false, "non-interactive: use flags and defaults")
	return cmd
}

func runPackageForm(p *tmpl.Package) error {
	form := huh.NewForm(
		huh.NewGroup(
			huh.NewInput().
				Title("Package name").
				Description("Attribute name for the package (e.g. mytool).").
				Value(&p.Name).
				Validate(wizard.ValidateIdent),
			huh.NewInput().
				Title("Description").
				Description("Short summary of what this package does (optional).").
				Value(&p.Description),
		),
	)
	return form.Run()
}

// ---- add feature ----

func newAddFeatureCmd() *cobra.Command {
	var (
		featType    string
		description string
		force       bool
		yes         bool
	)
	cmd := &cobra.Command{
		Use:   "feature [name]",
		Short: "Add an opt-in feature bundle (agnostic, darwin, nixos, hm, flake)",
		Args:  cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			w, root, err := openRepo(force)
			if err != nil {
				return err
			}
			f := tmpl.Feature{
				Type:        featType,
				Description: description,
			}
			if len(args) == 1 {
				f.Name = args[0]
			}
			if f.Type == "" {
				f.Type = "agnostic"
			}
			interactive := !yes && isTTY()
			if interactive {
				if err := runFeatureForm(&f); err != nil {
					return err
				}
			}
			f.Type = normalizeFeatureType(f.Type)
			if err := validateFeature(f); err != nil {
				return err
			}
			if err := gen.Feature(w, f); err != nil {
				return err
			}
			fmt.Fprintf(cmd.OutOrStdout(), "Added %s feature %q:\n", f.Type, f.Name)
			finish(cmd, w, root)
			return nil
		},
	}
	flags := cmd.Flags()
	flags.StringVarP(&featType, "type", "t", "agnostic", "feature type: agnostic, darwin, nixos, hm, flake")
	flags.StringVar(&featType, "kind", "agnostic", "alias for --type")
	flags.StringVarP(&description, "description", "d", "", "feature description")
	flags.BoolVar(&force, "force", false, "overwrite an existing file")
	flags.BoolVar(&yes, "yes", false, "non-interactive: use flags and defaults")
	return cmd
}

func runFeatureForm(f *tmpl.Feature) error {
	typeOpts := []huh.Option[string]{
		huh.NewOption("agnostic — Cross-platform settings bundle (NixOS + Darwin)", "agnostic"),
		huh.NewOption("darwin — nix-darwin settings bundle", "darwin"),
		huh.NewOption("nixos — NixOS settings bundle", "nixos"),
		huh.NewOption("hm — Home-manager user settings bundle", "hm"),
		huh.NewOption("flake — Flake-level wiring (devShells, inputs, checks)", "flake"),
	}
	form := huh.NewForm(
		huh.NewGroup(
			huh.NewInput().
				Title("Feature name").
				Description("Identifier for the feature bundle (e.g. dev-tools, theme).").
				Value(&f.Name).
				Validate(wizard.ValidateIdent),
			huh.NewSelect[string]().
				Title("Feature type").
				Description("Target category for this opt-in bundle.").
				Options(typeOpts...).
				Value(&f.Type),
			huh.NewInput().
				Title("Description").
				Description("Short summary of this feature bundle (optional).").
				Value(&f.Description),
		),
	)
	return form.Run()
}

func normalizeFeatureType(t string) string {
	switch strings.ToLower(strings.TrimSpace(t)) {
	case "home", "hm", "homemanager", "home-manager":
		return "hm"
	case "darwin", "nix-darwin":
		return "darwin"
	case "nixos":
		return "nixos"
	case "flake", "flake-parts":
		return "flake"
	default:
		return "agnostic"
	}
}

func validateFeature(f tmpl.Feature) error {
	if err := wizard.ValidateIdent(f.Name); err != nil {
		return fmt.Errorf("feature name: %w", err)
	}
	switch f.Type {
	case "agnostic", "darwin", "nixos", "hm", "flake":
		return nil
	default:
		return fmt.Errorf("invalid feature type %q; must be agnostic, darwin, nixos, hm, or flake", f.Type)
	}
}
