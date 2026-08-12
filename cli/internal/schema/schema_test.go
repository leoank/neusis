package schema

import "testing"

func TestSnapshotLoaded(t *testing.T) {
	cases := []struct{ cat, field, want string }{
		{"machine", "system", "architecture"},
		{"machine", "hostPubkey", "host public key"},
		{"user", "shell", "shell"},
		{"user", "username", "username"},
	}
	for _, c := range cases {
		got := Help(c.cat, c.field)
		if got == "" {
			t.Errorf("Help(%q,%q) empty — snapshot missing or malformed", c.cat, c.field)
			continue
		}
		if !contains(got, c.want) {
			t.Errorf("Help(%q,%q) = %q; want it to contain %q", c.cat, c.field, got, c.want)
		}
	}
}

func TestHelpOrFallback(t *testing.T) {
	if got := HelpOr("machine", "does-not-exist", "fb"); got != "fb" {
		t.Errorf("HelpOr fallback = %q; want fb", got)
	}
}

func contains(s, sub string) bool {
	for i := 0; i+len(sub) <= len(s); i++ {
		if s[i:i+len(sub)] == sub {
			return true
		}
	}
	return false
}
