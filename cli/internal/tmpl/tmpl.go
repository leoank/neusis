// Package tmpl holds the embedded scaffolding templates and the data
// models that drive them. Templates render valid Nix; Go's `{{ }}`
// action delimiters never collide with Nix's `${ }` interpolation.
package tmpl

import (
	"embed"
	"strings"
	"sync"
	"text/template"

	"github.com/leoank/neusis/cli/internal/source"
)

//go:embed files
var files embed.FS

// Repo describes a whole generated fleet repository (used by `init`).
type Repo struct {
	Name          string // flake description / project name
	Style         string // "dendritic" | "plain"
	NeusisRef     string // flake ref for the neusis library input
	NixpkgsRef    string
	HMRef         string
	DarwinRef     string
	IncludeDarwin bool // pull in the nix-darwin input
	Secrets       bool // set up agenix-rekey secrets infrastructure
	Systems       []string
}

// MasterIdentity is an agenix-rekey operator identity.
type MasterIdentity struct {
	IdentityPath string // string path to the private key (read at rekey time)
	Pubkey       string // its public key
}

// Lab describes a registry grouping (a lab / site).
type Lab struct {
	Name string
}

// Machine is one host atom.
type Machine struct {
	Name         string // attribute key (defaults to Hostname)
	Hostname     string
	System       string // e.g. "x86_64-linux", "aarch64-darwin"
	Platform     string // "nixos" | "darwin" (derived from System)
	ComputerName string // darwin only, optional
	HostPubkey   string
	PrimaryUser  string // optional
	Lab          string // registry lab this host joins
	StateVersion string // NixOS state version, e.g. "25.11"
	Secrets      bool   // wire the agenix-rekey secrets block for this host
}

// User is one person atom.
type User struct {
	Name     string // attribute key
	Username string
	FullName string
	Shell    string
	Role     string // "admin" | "regular" | "guest" | "locked"
	Lab      string
	KeyFile  string // relative nix path to a copied pubkey, or "" if none
}

// RolePlural maps a role to its registry list key (the userRegistryType
// option name). "locked" is irregular — its option is `locked`, not
// `lockeds`.
func (u User) RolePlural() string {
	if u.Role == "locked" {
		return "locked"
	}
	return u.Role + "s"
}

// IsDarwin reports whether the machine targets a Darwin system.
func (m Machine) IsDarwin() bool { return strings.HasSuffix(m.System, "darwin") }

var funcs = template.FuncMap{
	"nixStr": func(s string) string {
		r := strings.NewReplacer(`\`, `\\`, `"`, `\"`, `$`, `\$`)
		return `"` + r.Replace(s) + `"`
	},
}

var (
	parseMu sync.Mutex
	parsed  = map[string]*template.Template{}
)

// Files returns every template key (path relative to files/).
func Files() []string {
	names, err := allFiles("files")
	if err != nil {
		return nil
	}
	out := make([]string, 0, len(names))
	for _, n := range names {
		out = append(out, strings.TrimPrefix(n, "files/"))
	}
	return out
}

func allFiles(dir string) ([]string, error) {
	var out []string
	entries, err := files.ReadDir(dir)
	if err != nil {
		return nil, err
	}
	for _, e := range entries {
		p := dir + "/" + e.Name()
		if e.IsDir() {
			sub, err := allFiles(p)
			if err != nil {
				return nil, err
			}
			out = append(out, sub...)
			continue
		}
		out = append(out, p)
	}
	return out, nil
}

// Get returns the parsed template for key (path relative to files/),
// preferring a cached remote copy over the embedded one, or nil if the
// key is unknown. A malformed remote override falls back to embedded.
func Get(key string) *template.Template {
	parseMu.Lock()
	defer parseMu.Unlock()
	if t, ok := parsed[key]; ok {
		return t
	}
	embedded, err := files.ReadFile("files/" + key)
	if err != nil {
		return nil
	}
	b := source.Resolve("tmpl", key, embedded)
	t, err := template.New(key).Funcs(funcs).Parse(string(b))
	if err != nil {
		t = template.Must(template.New(key).Funcs(funcs).Parse(string(embedded)))
	}
	parsed[key] = t
	return t
}

// Specs lists the source refresh specs for every template file.
func Specs() []source.Spec {
	keys := Files()
	out := make([]source.Spec, 0, len(keys))
	for _, k := range keys {
		out = append(out, source.Spec{
			Subdir:     "tmpl",
			Rel:        k,
			RemotePath: "cli/internal/tmpl/files/" + k,
		})
	}
	return out
}
