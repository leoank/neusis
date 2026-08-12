# neusis CLI

The user-facing CLI for [neusis](https://github.com/leoank/neusis) —
scaffold and grow a NixOS/nix-darwin fleet repository that consumes
neusis as a library.

## Install

Single command (Linux / macOS, all architectures):

```bash
curl -fsSL https://raw.githubusercontent.com/leoank/neusis/main/cli/install.sh | sh
```

Or, with Nix:

```bash
nix run github:leoank/neusis#neusis -- init
```

Overrides for the install script: `NEUSIS_VERSION`, `NEUSIS_INSTALL_DIR`.

## Usage

```bash
neusis init [dir]        # create a new fleet repo (wizard)
neusis add machine       # add a host
neusis add user          # add a person
neusis add registry      # add a lab (grouping)
neusis add secrets       # set up agenix-rekey secrets
```

Every command runs as a wizard when invoked interactively, and accepts
flags (with `--yes`) for scripting. The CLI only reads and writes files;
it uses `nix` and `git` when present but never requires them.

## Development

```bash
go build -o neusis .     # build
go test ./...            # test
```

Wizard help text is derived from neusis's option schema. Regenerate the
snapshot after changing `new_modules/lib/neusis-options.nix`:

```bash
cd internal/schema
NEUSIS_ROOT=../../.. nix eval --impure --json -f extract.nix > files/schema.json
```

Releases are cut by tagging `v*`; GitHub Actions runs goreleaser
(`.goreleaser.yaml`) to publish per-OS/arch binaries.
