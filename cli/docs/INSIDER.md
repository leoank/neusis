# neusis CLI — Insider Docs

Design decisions, architecture, learnings, and a build log for the
`neusis` CLI. Written for maintainers (and future-us) — not end users.
For usage, see `cli/README.md`.

---

## 1. What the CLI is

A single, statically-linked Go binary that scaffolds and grows a
**neusis-library consumer repo** — a small NixOS/nix-darwin fleet repo
that imports neusis as a flake library rather than forking it.

Core commands:

- `neusis init [dir]` — create a new fleet repo (wizard or flags)
- `neusis add machine | user | registry | secrets`
- `neusis update` — refresh templates/schema from the neusis repo
- `neusis version`

Wizard-when-interactive, flags-when-scripted (`--yes`). It only reads
and writes files; it uses `nix`/`git`/`agenix` when present but never
requires them.

---

## 2. Language decision — Go

Chosen over Rust / a Nix-native TUI for these specific goals:

| Requirement | Why Go |
|---|---|
| Single `curl` install, all OS/arch | One static binary; trivial cross-compile; goreleaser + `install.sh` |
| Wizard with inline help | Charm ecosystem (`huh`, `bubbletea`, `lipgloss`) is best-in-class |
| Scaffolding | `text/template` + `go:embed` bake templates into the binary |
| Offline-first | No runtime; embedded fallbacks |

**Stack:** `cobra` (+ `fang` for styled help), `huh` (forms), `lipgloss`.

> Dependency gotcha: `fang` (new lipgloss-v2 / ultraviolet stack) and
> `huh` (older bubbletea) share `charmbracelet/x/ansi`. The default
> resolve pulled `cellbuf@v0.0.13` which breaks against `x/ansi@v0.11`.
> Fix: bump `x/cellbuf`→v0.0.15 and `bubbletea`→v1.3.10.

---

## 3. Design decisions (with rationale)

All of these were explicit choices, most made with the user in the loop.

1. **Registry-driven output, not the low-level example.** Generated
   repos declare `flake.neusis.machines/registry.*` and call
   `mkNeusisFlake`, mirroring neusis's own `machines/users/registry`
   layout — *not* the per-host `mkNeusisOS` style in
   `examples/flake-parts-consumer/`. This matches the user's vocabulary
   ("add machines/users/registries") and how neusis actually works.

2. **Self-registering atoms.** Each machine/user file both *defines*
   itself and *joins* its lab via flake-parts list-merge:

   ```nix
   flake.neusis.machines.oppy = { ... };
   flake.neusis.registry.machines.home.nixos = [ self.neusis.machines.oppy ];
   ```

   So `add` is a **pure append** — no fragile editing of a central
   registry file. A per-lab `registry/<lab>.nix` seeds empty lists so
   the lab attribute always exists.

3. **Two flake styles behind a flag.** `--style dendritic` (default,
   mirrors neusis: `flake-file` generates `flake.nix`, `import-tree`
   over `./modules`) and `--style plain` (static hand-written
   `flake.nix`, buildable without `nix`). Both share `import-tree` over
   `./modules`; the only difference is how `flake.nix` and inputs are
   declared.

4. **Layout.** `modules/{users,machines,registry}/*.nix`, one atom per
   file; `modules/systems.nix` = `deploy.nix` clone; `secrets/` at repo
   root.

5. **Help text auto-derived from the schema.** Wizard field help comes
   from an embedded JSON snapshot of the `mkOption` descriptions in
   `new_modules/lib/neusis-options.nix` (extracted via `evalModules` +
   `getSubOptions`), with concise built-in fallbacks. No hand-copied
   drift.

6. **Secrets = agenix-rekey, consumer-owned.** `init` scaffolds a
   `secrets/` tree; `--secrets` records a master identity in
   `secrets/master-identities.nix` (single shared source, imported by
   machines — avoids fragile flake plumbing). Machines in a
   secrets-enabled repo get the `neusis.services.secrets` block wired to
   the consumer's own storage dir + identity.

7. **Online-first with embedded fallback.** Templates and the schema
   snapshot are fetched from the neusis repo into a local cache
   (preferred), falling back to `go:embed` copies. Fully offline-safe.

8. **Graceful tool integration.** `write-flake`/`nix flake lock` are
   *offered* (or printed as hints) when `nix` is present; new files are
   `git add`-ed (nix ignores untracked files).

---

## 4. Package structure

```
cli/
├── main.go
├── cmd/            # cobra commands: root, init, add, update, version, common
├── internal/
│   ├── tmpl/       # go:embed templates + Repo/Machine/User/Lab models
│   │   └── files/  # {common,dendritic,plain}/*.tmpl
│   ├── schema/     # embedded option-schema snapshot + extract.nix
│   │   └── files/schema.json
│   ├── source/     # cache-first resolution + raw-GitHub refresh
│   ├── gen/        # models -> files (Repo, Machine, User, Lab, secrets)
│   ├── scaffold/   # idempotent file writer (tracks written/skipped)
│   ├── nix/        # nix/git detection, write-flake, git add
│   └── wizard/     # defaults, option catalogues, validation
├── .goreleaser.yaml
├── install.sh
└── docs/INSIDER.md
```

**Byte-resolution flow:** `tmpl.Get` / `schema.Help` →
`source.Resolve(subdir, rel, embedded)` → cache file if present, else
embedded. `source.MaybeRefresh` (TTL-gated, non-fatal) runs before
`init`/`add`; `neusis update` forces it.

---

## 5. What a generated repo looks like

Dendritic, secrets-enabled, one NixOS host + one admin:

```
my-fleet/
├── flake.nix               # generated by write-flake
├── flake.lock
├── modules/
│   ├── dendritic.nix       # flake-file + import-tree wiring; imports neusis.flakeModules.default
│   ├── systems.nix         # mkNeusisFlake -> {nixos,darwin,home}Configurations
│   ├── registry/home.nix   # seeds lab "home" (empty lists)
│   ├── machines/oppy.nix    # defines host + joins registry.machines.home.nixos
│   └── users/ank.nix        # defines user + joins registry.users.home.admins
└── secrets/
    ├── master-identities.nix
    ├── common/             # rekeyFiles (e.g. hashedInitialPassword.age)
    └── rekeyed/            # per-host rekeyed outputs
```

Verified end-to-end: a generated dendritic repo **fully evaluates**
against the real neusis library (NixOS + Darwin machines, user accounts
via the agenix password path, `system.primaryUser`, home configs).

---

## 6. neusis-core changes the CLI forced

The CLI was the first real *external consumer* of neusis-as-a-library,
which surfaced four issues in neusis core. All fixed here.

1. **`flakeModules.default` didn't export the integration modules.**
   The `neusisOS` builders reach for `self.{nixos,darwin}Modules.*`
   (`hm-system-init`, `secrets`), but `flakeModules.lib` only exported
   options + builders. Any consumer machine with users failed with
   `attribute 'hm-system-init' missing`. Fix: enriched
   `flakeModules.default` with `hm-system-init` + `secrets` +
   `re-export-all`. (`main-c63`)

2. **The secrets module hardcoded neusis's own paths.**
   `agnosticModules/secrets.nix` pinned `localStorageDir` and the
   distributed-build key to neusis's `secrets/` tree. Parameterized via
   `storageBaseDir` and `remoteBuildKeyFile` (defaults preserve neusis
   behavior; `remoteBuildKeyFile = null` opts out). (`main-fk4`)

3. **`initialHashedPassword` had a hidden, harmful default.** It
   defaulted to `../secrets/common/hashedInitialPassword.age` — *neusis's*
   secret, which consumers can't decrypt: builds evaluated fine and
   failed at activation. Made it an explicit `machineType` option (no
   default), threaded through `mkNeusisFlake → mkSystemPair →
   mkNeusisOS`, and `mkNeusisOS` now **asserts** it's set precisely when
   the host has login (non-locked) users, with an actionable message.
   (`main-71c`)

4. **The `locked` role was silently broken.** `pluralOf` did
   `role + "s"` → `lockeds`, but the registry option is `locked`. So
   `mkUserAccountModules` read a non-existent `lockeds` key (locked
   users were **never created as accounts**) and `mergeUserConfigs`
   emitted an invalid `lockeds` attribute. Fixed `pluralOf` (and the
   CLI's `RolePlural`) to special-case `locked → locked`.

> The plain-style consumer also hit a coupling: `hm-system-init.nix`
> declared `flake-file.inputs`, an option that only exists in a
> dendritic context. Removed the redundant declaration (home-manager is
> already declared in `homeModules/home-manager.nix`). (`main-cp8`)

---

## 7. Learnings / gotchas

- **`self` closure inside a machine's inline `module`.** The module
  function receives nixos/darwin `specialArgs` (`inputs`, `outputs`),
  not `self`. But an inline module *closes over* the outer flake-parts
  `self`, so `self.nixosModules.secrets` resolves via lexical scope.

- **Nix path literals are lazy.** A generated
  `initialHashedPassword = ../../secrets/common/hashedInitialPassword.age`
  evaluates fine even if the `.age` file doesn't exist yet — the path is
  only *realised* at build/activation. So generated secrets repos are
  eval-clean; the operator creates the actual secret before deploying.

- **`nix` ignores untracked files.** Any newly written module must be
  `git add`-ed before `nix eval` / `write-flake` sees it. The CLI stages
  with `git add --intent-to-add`.

- **buildGoModule names the binary after the module's last path
  segment** (`cli`). Renamed to `neusis` via `postInstall`.

- **flake-parts requires `systems`.** Declared in the generated
  `systems.nix` so consumer flakes don't error.

- **Bootstrap chicken/egg avoided.** For dendritic repos the CLI writes
  the *final* `flake.nix` directly (matching write-flake output) so the
  repo is usable before ever running `write-flake` — dodging the
  "flake.nix must exist to run write-flake, which references inputs
  flake.nix doesn't have yet" deadlock.

---

## 8. Distribution

Three channels, all verified:

- **`curl | sh`** — `install.sh` (OS/arch detect, latest-release
  resolution, PATH-aware dir) + `goreleaser` (linux/darwin × amd64/arm64,
  `neusis_<os>_<arch>.tar.gz` + checksums). `.github/workflows/cli-release.yml`
  runs goreleaser on `v*` tags.
- **Nix** — `flake.packages.<system>.neusis` (buildGoModule) →
  `nix run github:leoank/neusis#neusis`.
- Both honor `NEUSIS_VERSION` / `NEUSIS_INSTALL_DIR`.

---

## 9. Online refresh

- `internal/source`: layered `cache → embedded`; raw-GitHub fetch of the
  `.tmpl` files and `schema.json`.
- `neusis update` fetches into the XDG cache (`NEUSIS_REF` targets a
  branch/tag; default `main`; `NEUSIS_REPO` overrides the repo).
- `init`/`add` auto-refresh: TTL-gated (24h), short timeout (4s),
  non-fatal. `NEUSIS_OFFLINE` disables all network.
- A malformed remote override falls back to embedded per-file.

Verified: fetch (11 files from the `cli` branch), cache override during
generation, and embedded fallback with no cache/network.

---

## 10. Status & next steps

**Done & verified:** init + add {machine,user,registry,secrets}, both
flake styles, schema-derived help, agenix-rekey secrets, explicit
password handling, distribution (curl + nix + CI), online refresh. Four
neusis-core fixes landed.

**Open follow-ups (none blocking):**

- Merge `cli` → `main` so the default `main` ref serves templates/schema.
- Cut the first `v*` tag to exercise the release pipeline.
- Expand `add secrets` into full per-secret automation (create + wire +
  rekey), once the agenix-rekey flow is settled.

**Regenerating the schema snapshot** (after editing
`new_modules/lib/neusis-options.nix`):

```bash
cd cli/internal/schema
NEUSIS_ROOT=../../.. nix eval --impure --json -f extract.nix > files/schema.json
```

**Issue tracking:** beads epic `main-q8c` (closed) + fixes `main-c63`,
`main-fk4`, `main-71c`, `main-cp8`, `main-c0s`, `main-8mu`.
