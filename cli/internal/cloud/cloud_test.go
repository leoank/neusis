package cloud

import (
	"strings"
	"testing"
)

const sampleOutput = `{
  "instances": {
    "sensitive": false,
    "type": ["object", {}],
    "value": {
      "ghost001": {"ocid": "ocid1.instance.oc1..x", "private_ip": "10.42.0.5", "public_ip": "203.0.113.7"}
    }
  }
}`

func TestParseInstanceIP(t *testing.T) {
	ip, err := ParseInstanceIP([]byte(sampleOutput), "ghost001")
	if err != nil || ip != "203.0.113.7" {
		t.Fatalf("got %q, %v", ip, err)
	}
	if _, err := ParseInstanceIP([]byte(sampleOutput), "nope"); err == nil || !strings.Contains(err.Error(), "ghost001") {
		t.Fatalf("expected an error naming the known instances, got %v", err)
	}
	if _, err := ParseInstanceIP([]byte(`{"instances":{"value":{"ghost001":{"ocid":"x"}}}}`), "ghost001"); err == nil {
		t.Fatal("expected an error for a missing public_ip")
	}
	if _, err := ParseInstanceIP([]byte(`not json`), "ghost001"); err == nil {
		t.Fatal("expected a JSON error")
	}
}

func TestKeyFieldsAndKnownHosts(t *testing.T) {
	registry := "ssh-ed25519 AAAAC3Nza root@ghost001"
	scanned := "ssh-ed25519 AAAAC3Nza"
	if KeyFields(registry) != KeyFields(scanned) {
		t.Fatalf("comments must not matter: %q vs %q", KeyFields(registry), KeyFields(scanned))
	}
	if got := KnownHostsLine("203.0.113.7", registry); got != "203.0.113.7 ssh-ed25519 AAAAC3Nza\n" {
		t.Fatalf("unexpected known_hosts line %q", got)
	}
}

func TestNixosRebuildArgs(t *testing.T) {
	got := strings.Join(NixosRebuildArgs("/repo", "ghost001", "root@203.0.113.7", false), " ")
	want := "switch --flake /repo#ghost001 --target-host root@203.0.113.7"
	if got != want {
		t.Fatalf("got %q want %q", got, want)
	}
	if got := NixosRebuildArgs("/repo", "ghost001", "root@h", true); got[len(got)-2] != "--build-host" || got[len(got)-1] != "root@h" {
		t.Fatalf("build-host not appended: %v", got)
	}
}
