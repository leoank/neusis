// Package schema exposes an embedded snapshot of neusis's option
// descriptions (from new_modules/lib/neusis-options.nix), used as the
// source of truth for wizard help text. Regenerate files/schema.json
// with extract.nix — see that file's header.
package schema

import (
	_ "embed"
	"encoding/json"
)

//go:embed files/schema.json
var raw []byte

type snapshot struct {
	Machine map[string]string `json:"machine"`
	User    map[string]string `json:"user"`
}

var data = func() snapshot {
	var s snapshot
	_ = json.Unmarshal(raw, &s)
	return s
}()

// Help returns the schema description for field in category
// ("machine" or "user"), or "" if absent.
func Help(category, field string) string {
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
