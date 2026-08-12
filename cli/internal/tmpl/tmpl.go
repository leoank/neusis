// Package tmpl holds the embedded scaffolding templates and the data
// models that drive them. Templates render valid Nix; Go's `{{ }}`
// action delimiters never collide with Nix's `${ }` interpolation.
package tmpl

import (
	"embed"
	"strings"
	"text/template"
)

//go:embed files
var files embed.FS

// Repo describes a whole generated fleet repository (used by `init`).
type Repo struct {
	Name         string // flake description / project name
	Style        string // "dendritic" | "plain"
	NeusisRef    string // flake ref for the neusis library input
	NixpkgsRef   string
	HMRef        string
	DarwinRef    string
	IncludeDarwin bool // pull in the nix-darwin input
	Systems      []string
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

// RolePlural maps a role to its registry list key.
func (u User) RolePlural() string { return u.Role + "s" }

// IsDarwin reports whether the machine targets a Darwin system.
func (m Machine) IsDarwin() bool { return strings.HasSuffix(m.System, "darwin") }

var funcs = template.FuncMap{
	"nixStr": func(s string) string {
		r := strings.NewReplacer(`\`, `\\`, `"`, `\"`, `$`, `\$`)
		return `"` + r.Replace(s) + `"`
	},
}

// tmpls parses every embedded template once, keyed by its path under
// files/ (e.g. "common/systems.nix.tmpl").
var tmpls = func() map[string]*template.Template {
	out := map[string]*template.Template{}
	entries, err := allFiles("files")
	if err != nil {
		panic(err)
	}
	for _, name := range entries {
		b, err := files.ReadFile(name)
		if err != nil {
			panic(err)
		}
		key := strings.TrimPrefix(name, "files/")
		out[key] = template.Must(template.New(key).Funcs(funcs).Parse(string(b)))
	}
	return out
}()

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

// Get returns the parsed template registered under key (path relative to
// files/), or nil if absent.
func Get(key string) *template.Template { return tmpls[key] }
