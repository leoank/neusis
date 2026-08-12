// Package gen renders neusis repository artifacts (a whole repo, or a
// single machine/user/lab atom) into a target directory via the
// scaffold writer.
package gen

import (
	"fmt"

	"github.com/leoank/neusis/cli/internal/scaffold"
	"github.com/leoank/neusis/cli/internal/tmpl"
)

func render(w *scaffold.Writer, relPath, tmplKey string, data any) error {
	t := tmpl.Get(tmplKey)
	if t == nil {
		return fmt.Errorf("template %q not found", tmplKey)
	}
	return w.Render(relPath, t, data)
}

// Repo scaffolds the skeleton of a new fleet repository.
func Repo(w *scaffold.Writer, r tmpl.Repo) error {
	flakeTmpl := "plain/flake.nix.tmpl"
	if r.Style == "dendritic" {
		flakeTmpl = "dendritic/flake.nix.tmpl"
	}
	if err := render(w, "flake.nix", flakeTmpl, r); err != nil {
		return err
	}
	if r.Style == "dendritic" {
		if err := render(w, "modules/dendritic.nix", "dendritic/dendritic.nix.tmpl", r); err != nil {
			return err
		}
	}
	if err := render(w, "modules/systems.nix", "common/systems.nix.tmpl", r); err != nil {
		return err
	}
	if err := render(w, ".gitignore", "common/gitignore.tmpl", r); err != nil {
		return err
	}
	if err := render(w, "README.md", "common/README.md.tmpl", r); err != nil {
		return err
	}
	// Every repo gets a secrets/ skeleton; the agenix-rekey wiring
	// (master-identities.nix) is only written when secrets are enabled.
	if err := SecretsSkeleton(w); err != nil {
		return err
	}
	return nil
}

// SecretsSkeleton creates the empty secrets/ folder structure. Safe to
// call repeatedly.
func SecretsSkeleton(w *scaffold.Writer) error {
	for _, p := range []string{"secrets/common/.gitkeep", "secrets/rekeyed/.gitkeep"} {
		if err := w.WriteFile(p, nil); err != nil {
			return err
		}
	}
	return nil
}

// MasterIdentities writes secrets/master-identities.nix — the marker
// that a repo is secrets-enabled. Presence of this file is what
// SecretsEnabled checks.
func MasterIdentities(w *scaffold.Writer, id tmpl.MasterIdentity) error {
	if err := SecretsSkeleton(w); err != nil {
		return err
	}
	return render(w, "secrets/master-identities.nix", "common/master-identities.nix.tmpl", id)
}

// Lab scaffolds a registry lab file.
func Lab(w *scaffold.Writer, l tmpl.Lab) error {
	return render(w, "modules/registry/"+l.Name+".nix", "common/registry.nix.tmpl", l)
}

// Machine scaffolds a host file.
func Machine(w *scaffold.Writer, m tmpl.Machine) error {
	return render(w, "modules/machines/"+m.Name+".nix", "common/machine.nix.tmpl", m)
}

// User scaffolds a person file.
func User(w *scaffold.Writer, u tmpl.User) error {
	return render(w, "modules/users/"+u.Name+".nix", "common/user.nix.tmpl", u)
}
