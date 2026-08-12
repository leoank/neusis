// Package source resolves templates and the schema snapshot from a
// layered source: a locally cached copy fetched from the neusis repo
// (preferred) falling back to the binary's embedded copy. This lets the
// CLI pick up template/schema updates without a new release while still
// working fully offline.
package source

import (
	"context"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"time"
)

const (
	defaultRepo  = "leoank/neusis"
	defaultRef   = "main"
	cacheTTL     = 24 * time.Hour
	fetchTimeout = 4 * time.Second
)

func repo() string {
	if r := os.Getenv("NEUSIS_REPO"); r != "" {
		return r
	}
	return defaultRepo
}

func ref() string {
	if r := os.Getenv("NEUSIS_REF"); r != "" {
		return r
	}
	return defaultRef
}

// Offline reports whether network refresh is disabled (NEUSIS_OFFLINE).
func Offline() bool { return os.Getenv("NEUSIS_OFFLINE") != "" }

func cacheRoot() (string, error) {
	base, err := os.UserCacheDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(base, "neusis"), nil
}

// Resolve returns the cached bytes for subdir/relpath when present,
// otherwise the supplied embedded bytes.
func Resolve(subdir, relpath string, embedded []byte) []byte {
	if root, err := cacheRoot(); err == nil {
		p := filepath.Join(root, subdir, filepath.FromSlash(relpath))
		if b, err := os.ReadFile(p); err == nil {
			return b
		}
	}
	return embedded
}

// Spec describes one fetchable file: where it lives under the repo and
// where it caches locally.
type Spec struct {
	Subdir     string // cache subdir, e.g. "tmpl" or "schema"
	Rel        string // slash path within Subdir
	RemotePath string // path under the repo, e.g. cli/internal/tmpl/files/...
}

func rawURL(remotePath string) string {
	return "https://raw.githubusercontent.com/" + repo() + "/" + ref() + "/" + remotePath
}

// Refresh fetches every spec into the cache, overwriting on success and
// leaving the existing cache/embedded copy untouched on failure. It
// returns the number of files fetched. A stamp is written so MaybeRefresh
// can rate-limit.
func Refresh(ctx context.Context, specs []Spec) (int, error) {
	root, err := cacheRoot()
	if err != nil {
		return 0, err
	}
	client := &http.Client{}
	fetched := 0
	for _, s := range specs {
		data, ok := get(ctx, client, rawURL(s.RemotePath))
		if !ok {
			continue
		}
		dst := filepath.Join(root, s.Subdir, filepath.FromSlash(s.Rel))
		if err := writeAtomic(dst, data); err == nil {
			fetched++
		}
	}
	_ = writeAtomic(filepath.Join(root, ".stamp"), []byte(""))
	return fetched, nil
}

// MaybeRefresh does a best-effort, TTL-gated refresh unless offline. All
// errors are swallowed: the caller always proceeds with whatever the
// cache/embedded resolution yields.
func MaybeRefresh(specs []Spec) {
	if Offline() || !stale() {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), fetchTimeout)
	defer cancel()
	_, _ = Refresh(ctx, specs)
}

func stale() bool {
	root, err := cacheRoot()
	if err != nil {
		return false // no cache dir → never try to refresh
	}
	fi, err := os.Stat(filepath.Join(root, ".stamp"))
	if err != nil {
		return true
	}
	return time.Since(fi.ModTime()) > cacheTTL
}

func get(ctx context.Context, client *http.Client, url string) ([]byte, bool) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, false
	}
	resp, err := client.Do(req)
	if err != nil {
		return nil, false
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, false
	}
	b, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, false
	}
	return b, true
}

func writeAtomic(dst string, data []byte) error {
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return err
	}
	tmp := dst + ".tmp"
	if err := os.WriteFile(tmp, data, 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, dst)
}

// Location reports the effective repo and ref used for refresh, for
// display in `neusis update`.
func Location() (repoName, refName string) { return repo(), ref() }
