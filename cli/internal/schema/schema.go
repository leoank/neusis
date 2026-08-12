// Package schema exposes an embedded snapshot of neusis's option
// descriptions (from new_modules/lib/neusis-options.nix), used as the
// source of truth for wizard help text. Regenerate files/schema.json
// with extract.nix — see that file's header.
package schema

import (
	_ "embed"
	"encoding/json"
	"sync"

	"github.com/leoank/neusis/cli/internal/source"
)

//go:embed files/schema.json
var embedded []byte

type snapshot struct {
	Machine map[string]string `json:"machine"`
	User    map[string]string `json:"user"`
}

var (
	loadOnce sync.Once
	data     snapshot
)

// load resolves the snapshot, preferring a cached remote copy over the
// embedded one, and falling back to embedded on a malformed override.
// Lazy so a same-run refresh (before first use) is picked up.
func load() {
	raw := source.Resolve("schema", "schema.json", embedded)
	if json.Unmarshal(raw, &data) != nil {
		_ = json.Unmarshal(embedded, &data)
	}
}

// Spec is the source refresh spec for the schema snapshot.
func Spec() source.Spec {
	return source.Spec{
		Subdir:     "schema",
		Rel:        "schema.json",
		RemotePath: "cli/internal/schema/files/schema.json",
	}
}

// Help returns the schema description for field in category
// ("machine" or "user"), or "" if absent.
func Help(category, field string) string {
	loadOnce.Do(load)
	switch category {
	case "machine":
		return data.Machine[field]
	case "user":
		return data.User[field]
	}
	return ""
}

// HelpOr returns the schema description for a field, falling back to
// fallback when the snapshot has nothing for it.
func HelpOr(category, field, fallback string) string {
	if h := Help(category, field); h != "" {
		return h
	}
	return fallback
}
