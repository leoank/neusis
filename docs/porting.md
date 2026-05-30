# Porting Notes

A working journal of the migration from the legacy layout (`modules/`,
`machines/`, `homes/`, `users/`, root-level `secrets/`, `lib/`) to the
dendritic / flake-parts layout under `new_modules/`. Read
[`overview.md`](./overview.md) first for the high-level structure; this
file collects what bit us along the way and how to avoid it.

## Where things live now

```
new_modules/
├── dendritic.nix              # enables the dendritic pattern (flake-file)
├── flakeModules.nix           # exports flake.flakeModules.{options,lib,default}
├── home-manager.nix           # pulls in home-manager flake module
├── system-pkgs.nix            # configures nixpkgs per-system
├── lib/
│   ├── neusis-options.nix     # SCHEMA: declares flake.neusis (typed submodule)
│   ├── neusisOS.nix           # IMPL:   config.flake.neusis.lib.neusisOS = rec { ... }
│   └── utils.nix              # IMPL:   config.flake.neusis.lib.utils = { ... }
├── users/                     # per-user flake.neusis.users.<u>.neusisOS entries
├── registry/                  # per-lab flake.neusis.registry.* groupings
├── nixosModules/              # (in progress) NixOS modules ported from old modules/nixos/
└── hmModules/                 # home-manager modules
```

The root `flake.nix` is **generated** by `flake-file` — never hand-edit
it. Add inputs from inside any module via `flake-file.inputs.<name> = …`
and re-run `nix run .#write-flake`.

## The single most important rule

**Any flake-parts module that writes under a namespace must also import
the options module that declares that namespace's type.**

If `flake.neusis` has no declared option, flake-parts gives it freeform
`raw` semantics. Two files writing `flake.neusis.lib.neusisOS = …` and
`flake.neusis.lib.utils = …` then fail to merge with:

```
error: The option `flake.neusis' is defined multiple times while it's
expected to be unique. No option has been declared for this flake
output attribute, so its definitions can't be merged automatically.
```

Fix: every `flake.flakeModules.<name>` whose imports write under
`flake.neusis.*` must also import `./lib/neusis-options.nix`. See
`new_modules/flakeModules.nix` — `options`, `lib`, and `default` all
include the schema.

## Other gotchas worth memorizing

### `path:` inputs only see git-tracked files

When you create a new file under `new_modules/`, the consumer flakes
(via `neusis.url = "path:../.."` or any flake input) won't see it until
you `git add` it. Symptom is usually:

```
error: path '/nix/store/<hash>-source/new_modules/<file>' does not exist
```

…on a file you can clearly see on disk. Run `git add <file>` and then
`nix flake update neusis` in the consumer.

### `import-tree` excludes paths containing `/_`

Useful when porting data files (encrypted secrets, raw assets) into
`new_modules/` alongside the code that owns them. Put them under a
sibling directory whose name starts with `_` and `import-tree` will
skip the whole subtree:

```
new_modules/nixosModules/secrets.nix          # picked up
new_modules/nixosModules/_secrets-data/...    # skipped — leading "_"
```

Same trick for any `.nix` file you do NOT want flake-parts to interpret
as a module (e.g. an agenix recipients file, which is a plain attrset
not a module).

### `flake.flakeModules.<name>` must be a real module

Initial version was `flake.flakeModules.neusis = { lib = self.lib.neusisOS; }`
— that's not a module, it's an arbitrary attrset, and `imports` would
choke on it from a consumer. A proper export looks like:

```nix
flake.flakeModules.default = {
  imports = [
    ./lib/neusis-options.nix    # schema FIRST
    ./lib/neusisOS.nix
    ./lib/utils.nix
  ];
};
```

We currently export three:

- `options` — schema only (use when you want neusis's types but your own builders)
- `lib`     — schema + lib implementation
- `default` — same as `lib` today; idiomatic entry point

### `lazyAttrsOf raw` for lib namespaces

`flake.neusis.lib` is declared as `lazyAttrsOf raw`. Top-level keys
(`neusisOS`, `utils`) merge as distinct slots, but each namespace's
*value* is `raw` — no internal merging. Each namespace must come from
a single file, typically using `rec { ... }` for internal references.

### `lazyAttrsOf deferredModule` for module-list registries

Used for things like per-machine home-manager bundles
(`flake.neusis.users.<u>.hmBundles.<m>`) where each value is a module
body to be `imports`-ed later. Accepts both attrset literals and
paths-to-modules.

## Schema cheat sheet (`flake.neusis.*`)

```
flake.neusis.users.<u>.neusisOS.{username,fullName,shell,sshKeys,homeModules}
flake.neusis.users.<u>.hmBundles.<bundle>          # deferred module
flake.neusis.registry.users.<lab>.{admins,regulars,locked,guests}   # listOf deferredModule
flake.neusis.registry.machines.<lab>.{nixosConfigurations,darwinConfigurations}  # raw
flake.neusis.lib.<namespace>                       # raw (no internal merge)
```

`username` defaults to the attribute name via the submodule `{ name, ... }:`
binder, so most users only need `fullName` and the rest.

## Consumer access pattern

A downstream flake using neusis sees the namespace as `outputs.neusis`,
which flake-parts derives from `flake.neusis.*`. From a non-flake-parts
consumer that means:

```nix
inputs.neusis.neusis.lib.utils.helloWorld
#         │       │
#         │       └─ outputs.neusis (from `flake.neusis.*`)
#         └───────── the input named `neusis`
```

The doubled `neusis.neusis` reads weirdly but is correct. To avoid it,
either:

1. Rename the input: `inputs.nu.url = ...; → nu.neusis.lib.utils.…`
2. Add a top-level alias `flake.lib = flake.neusis.lib` (needs its own
   option declaration to avoid the merge-conflict trap above).

From a flake-parts consumer it's cleaner — import
`inputs.neusis.flakeModules.default` and use `config.flake.neusis.lib.…`
directly inside any module.

## Examples

- `examples/external-flake/` — plain (non-flake-parts) consumer. Uses
  `neusis.neusis.lib.neusisOS.mkNeusisOS` directly. Includes a smoke
  test under `.#hello` that calls `neusis.lib.utils.helloWorld`.
- `examples/flake-parts-consumer/` — flake-parts consumer using the
  typed schema. Splits config across `modules/{users,registry,systems}.nix`.

Verify either by running `nix eval .#<output>` from inside the example
directory. Update its lock with `nix flake update neusis` after any
schema-affecting change in the main repo.

## Open WIP gaps (as of writing)

These will trip up the next person — fix them or work around them, but
don't be surprised:

- **`mkNeusisDarwinOS` is broken.** `new_modules/lib/neusisOS.nix`
  references `inputs.darwin.lib.darwinSystem`, but `darwin` is not a
  declared flake input. Add it via `flake-file.inputs.darwin` (e.g.
  `github:lnl7/nix-darwin/master`) before this code path can evaluate.
- **`initialHashedPassword` default is wrong.** `mkNeusisOS` defaults
  `initialHashedPassword = ../secrets/common/hashedInitialPassword.age`,
  resolving from `new_modules/lib/` to `new_modules/secrets/` — a path
  that doesn't exist. Until secrets are ported, every caller must
  override this argument explicitly.
- **Field-name inconsistency.** `users-options.nix` declares
  `homeModules` (attrs of module-lists), but
  `users/ank/neusisOS.nix` sets `machineToBundlesMap`, and
  `lib/neusisOS.nix:35` reads `machineToBundleMap` (singular). Pick one
  and propagate.
- **Duplicate lab entries.** `registry/users/cslab.nix` and
  `registry/users/cslab_karkinos.nix` both write
  `flake.neusis.registry.users.cslab` — submodule merging concatenates
  the lists, so `ank`/`amunoz`/`shsingh` currently appear twice in the
  merged result. Split by cohort, not by machine.
- **`registry/machines/anklab.nix`** references
  `self.neusis.machines.<host>` which has no corresponding option in
  `neusis-options.nix`. Either add a `machines` option to the schema
  or rewrite anklab.nix to point at concrete module paths.

## Tips for the next porting pass

- **Test in isolation first.** Before wiring a ported module into a
  machine config, evaluate the flake output it produces:
  `nix eval .#neusis.<path>` will surface schema errors fast.
- **Stage early, stage often.** Every new file → `git add` immediately.
  The Nix `path:` and `git+file:` inputs cache aggressively and ignore
  untracked files. You'll burn 20 minutes wondering why your change
  isn't picked up.
- **Move data files with `_` prefix.** When porting a directory that
  mixes Nix modules and non-module data (encrypted secrets, raw files,
  legacy attrsets), put the non-module content under a sibling
  `_<name>/` directory so `import-tree` skips it.
- **Read `neusis-options.nix` before adding new options.** When the
  schema grows, prefer extending the existing `userType`,
  `userRegistryType`, etc. over declaring loose `flake.neusis.<new>`
  attributes. Loose attributes hit the freeform/merge trap eventually.
- **Don't trust the doubled `neusis.neusis`.** When updating examples
  or downstream docs, walk through the access path manually — it's
  easy to write `neusis.lib.…` and have it silently resolve to nothing.
- **`bd ready` and `bd remember`.** Per AGENTS.md, use beads for task
  tracking and persistent knowledge — not TodoWrite, not MEMORY.md
  files, not random scratch markdown.

---

## 2026-05-31 — schema, builder refactor, supercharged-git suite

Big session. The bulk of the "Open WIP gaps" above were closed and a
sizeable home-manager toolkit landed. Notes below capture both
*what* changed and the *why* behind the non-obvious calls, since
several were follow-ons to subtle eval-time bugs.

### Schema additions / changes (`new_modules/lib/neusis-options.nix`)

- **`flake.agnosticModules`** — `lazyAttrsOf deferredModule`. Modules
  that touch only options present on both NixOS and nix-darwin.
  Re-exported as `flake.{nixos,darwin}Modules` by
  `new_modules/agnosticModules/re-export-all.nix`.
- **`flake.neusis.machines.<name>`** typed as `machineType` with
  `hostname` (defaults to attr key), `computerName` (nullable, Darwin
  only), `hostPubkey` (required), `system` (default `x86_64-linux`),
  `nixpkgs` (`nullOr raw`), `primaryUser` (`nullOr str`),
  `modulesSpecialArgs`, `module` (deferred), and `userRegistries`
  (`listOf userRegistryType`). Closes the "anklab references
  `self.neusis.machines.<host>` with no option" gap.
- **`machineRegistryType`** retyped: was
  `nixosConfigurations`/`darwinConfigurations` attrsets-of-raw; now
  `nixos`/`darwin` *lists of `machineType`*. Far easier to iterate.
- **`flake.neusis.features.{nixos,darwin,agnostic,hm,flake}`** —
  each `lazyAttrsOf deferredModule`. Mirrors the actual layout under
  `new_modules/features/`.
- **`userType.neusisOS.machineToBundlesMap`** replaces the old
  `homeModules` field. Same `lazyAttrsOf (listOf deferredModule)`
  shape; the rename is to make the *meaning* explicit (bundles, keyed
  by hostname, with no implicit hmBundles-name-equals-hostname rule).
- **`userRegistryType.{admins,regulars,locked,guests}`** retyped
  from `listOf deferredModule` → **`listOf attrs`**. See the
  deferredModule-merge note in [Patterns] below — using
  `deferredModule` for *data* attrsets silently wraps every entry in
  `{ imports = [orig]; }`, and `mkAdmin adminConfig.username` then
  errors with "attribute 'username' missing".
- **Removed `flake.neusis.darwin.primaryUser`** (flake-wide
  setting); moved to `machineType.primaryUser` (per-machine).
  Builders inject `system.primaryUser = lib.mkDefault primaryUser`
  on Darwin when set. Feature modules read via
  `config.system.primaryUser` instead of `self.neusis.darwin.…`.

### Library refactor (`new_modules/lib/neusisOS.nix`)

Went from ~420 lines of duplicated builders to ~300 lines of
extracted helpers + thin public functions. Public API is stable;
private helpers live in a top-level `let`.

- **Four user builders → one `mkUser`.** `mkAdmin`/`mkRegular`/
  `mkGuest`/`mkLocked` were ~95% identical; replaced with a single
  `mkUser` keyed by a `roleSpecs` catalogue (`extraGroups` list per
  role, plus `locked = true` for the no-login variant). The four
  named functions stay as thin aliases (`mkAdmin = mkUser "admin"`)
  for backwards compatibility.
- **`mkNeusisFlake { machineRegistries }`** — new top-level function
  that produces `{ nixosConfigurations; darwinConfigurations;
  homeManagerConfigurations }` from the `flake.neusis.registry.machines`
  attrset. Removes the need for callers to spell out per-host build
  invocations.
- **NixOS-only `users.users.<name>` options gated on
  `pkgs.stdenv.isDarwin`** — `isNormalUser`,
  `hashedPasswordFile`/`hashedPassword`, `extraGroups`, the
  `pkgs.shadow`-based locked-account shell. Darwin gets
  `home = "/Users/<name>"` injected because nix-darwin doesn't
  default `users.users.<name>.home` (this was the root cause of a
  later home-manager `home.homeDirectory = null` failure — see
  [Patterns]).
- **`homeManager` flag dropped.** `mkHmInitModules` now keys off
  `userRegistries != []`; if you have users, you get home-manager
  wiring. Simpler call sites.
- **Per-machine `nixpkgs` override.** `mkNeusisOS` accepts a
  `nixpkgs` arg (`null` falls back to `inputs.nixpkgs`) and uses
  `chosenNixpkgs.lib.nixosSystem` — module system and pkgs travel
  together. `mkNeusisDarwinOS` accepts the arg only for signature
  parity and **asserts `nixpkgs == null`**: nix-darwin's nixpkgs is
  wired via the `darwin` input's `nixpkgs.follows`, not per-machine.
  Workaround for varying Darwin nixpkgs is to declare a second
  `darwin` input with a different follows.
- **`mkSpecialArgs`** helper threads `{ inherit inputs; outputs = self; }`
  into every NixOS/Darwin/HM module — so any downstream module can
  destructure `{ outputs, inputs, … }` and reach the rest of the
  flake.
- **Dead code removed.** `mkHomeManagerUser`, `mkHomeConfigurations`,
  the unused `machineName` arg in `mkDynamicUsers`.

### hm-system-init agnostic module (`new_modules/agnosticModules/`)

- **`hm-system-init.nix`** auto-populates `home-manager.users.<u>`
  from each user's `machineToBundlesMap.<hostname>`. Reads `outputs`
  + `inputs` from specialArgs and ships
  `home-manager.sharedModules = [ { home.stateVersion = mkDefault
  defaultStateVersion; } ]` so per-bundle stateVersion is no longer
  required boilerplate.
- **`re-export-all.nix`** — one-liner doing
  `flake.{nixos,darwin}Modules = config.flake.agnosticModules`. Means
  any new agnosticModule is automatically usable as both a NixOS and
  a Darwin module.
- **Platform-specific home-manager flake module import moved into
  the builders.** Previously `hm-system-init` itself did
  `if pkgs.stdenv.isDarwin then darwinModules.home-manager else
  nixosModules.home-manager` inside `imports`. That triggers infinite
  recursion (see [Patterns]). The split now: builders import the
  platform-correct home-manager flake module *before* the agnostic
  `hm-system-init`, which only touches
  `home-manager.users.<u>.imports` (same option name on both
  platforms).

### Features layout fixes (`new_modules/features/`)

- **`features/darwin/default.nix`** registered `darwin.system-defaults`
  (collided with `system-defaults.nix`) AND self-imported. Renamed to
  `darwin.defaults` to match the consumer reference in
  `machines/rogue.nix`.
- **`features/agnostic/nix-pkgs.nix`** registered as
  `agnostic.nix-settings` (collision with the real
  `nix-settings.nix`). Fixed to register `agnostic.nix-pkgs`.

### supercharged-git home-manager suite

Ported `homes/common/dev/git.nix` to `homeModules/supercharged-git.nix`
and grew it into an opt-in toolkit:

- Umbrella (`supercharged-git.nix`) — SSH-signed commits, LFS,
  allowed_signers, plus imports of every tool sub-module. Ships
  `gclb` on PATH unconditionally (see below).
- Tool sub-modules under `homeModules/supercharged-git/`:
  - `gh`, `gh-dash`, `lazygit`, `delta`, `pre-commit`,
    `commitizen`, `jujutsu`, `act`, `mergiraf`, `gitleaks`,
    `graphite`, `multi-account`, `bootstrap-repos`. Each registers
    `flake.homeModules.supercharged-git-<tool>` so they can be
    imported individually too.
  - `difftastic` was implemented then removed at the user's request
    (delta-only setup); leave the pattern as a record if someone
    wants a non-delta diff renderer.
- `multi-account` wires up per-account SSH host aliases, per-directory
  git identity via `programs.git.includes`, and URL rewriting via
  `programs.git.settings.url.<alias>:.insteadOf`.
- `bootstrap-repos` generates a `gclb-sync` script (via
  `pkgs.writeShellApplication`) that clones every declared repo into
  `<location>/<dest>/.bare/` via `gclb`. Idempotent — skips
  already-cloned `.bare` dirs. Optional `autoRun` runs it during HM
  activation via `lib.hm.dag.entryAfter ["writeBoundary"]`.
- Tutorial at `docs/supercharged-git/tutorial.md` (per-tool sections
  + putting-it-all-together).

### `gclb` package (`new_modules/packages/gclb/`)

- Python script for "bare clone + worktree bootstrap" workflow.
  Originally `homes/common/dev/gclb.py`, ported as a flake-parts
  **perSystem** package:
  ```nix
  perSystem = { pkgs, ... }: {
    packages.gclb = pkgs.writers.writePython3Bin "gclb" {} (builtins.readFile ./gclb.py);
  };
  ```
- Rewrote the Python: extracted helpers (`parse_repo_name`, `git`,
  `default_branch`, `write_gitfile`); switched
  `git remote show origin` → `git symbolic-ref --short HEAD` (no
  extra network round-trip); added `text=True` everywhere
  (eliminating the `bytes.__str__()` + `replace("\\n", "")` hack);
  replaced `assert` with `RuntimeError`; added idempotency check
  (refuses to overwrite existing `.git`/`.bare`); wrapped subprocess
  errors into friendly stderr messages.
- The umbrella references it as
  `outputs.packages.${pkgs.stdenv.hostPlatform.system}.gclb`, so
  any home-manager bundle that enables `neusis.supercharged-git` gets
  `gclb` automatically.
- Earlier draft used an overlay (`flake.overlays.gclb`); reverted at
  user's request — flake-parts perSystem is the canonical path.

### Patterns we burned hours rediscovering

Add these to your mental cache before the next session.

- **Infinite recursion from `pkgs.stdenv.isDarwin` in `imports`.**
  `pkgs` comes from `_module.args.pkgs`, which is a *config* value.
  Reading it inside `imports` forces config evaluation, which
  requires processing imports — cycle. Nix's error message even
  spells it out: *"if you get an infinite recursion here, you
  probably reference `config` in `imports`"*. Push platform
  branching *out of the agnostic module* and into the builders, or
  use a specialArg flag.
- **Infinite recursion from `self.<missing-key>`.** `self` is a
  recursive fixed point. Looking up a non-existent key forces Nix to
  evaluate `self` enough to know its key set, which means evaluating
  every flake-parts module's `flake.*` contribution — including the
  one that's currently trying to read `self.foo`. Fix: use
  `config.flake.foo` (reads the in-progress merge config, no full
  self eval) or only read keys that genuinely exist.
- **`listOf deferredModule` for data attrsets is wrong.**
  `deferredModule`'s `merge` wraps every value as
  `{ imports = [originalValue]; }`. So if you store
  `{ username = "ank"; … }` in a `listOf deferredModule`, reading
  the list back gives a list of `{ imports = […]; }`, and
  `entry.username` is missing. Use `listOf attrs` (or a real typed
  submodule) for data; reserve `deferredModule` for things that
  actually *are* modules.
- **nix-darwin doesn't default `users.users.<n>.home`.** NixOS auto
  fills `/home/<n>`; nix-darwin leaves it `null`. Home-manager's
  Darwin integration then sets `home.homeDirectory = null` and
  fails type-check ("not of type `absolute path`"). Setting
  `home.homeDirectory` *inside the bundle* doesn't save you — the
  bad definition from
  `home-manager.darwinModules.home-manager`'s common.nix is
  type-checked *before* merging, so the error fires before your
  override is considered. Seed
  `users.users.<n>.home = "/Users/<n>"` at the system level — done
  in `mkUser` already.
- **`programs.git.settings` is new (home-manager ≥ 25.05).** Older
  setups use `programs.git.extraConfig`. We target 25.11, so
  `settings` is fine; if you ever pin home-manager older, swap.
- **`programs.git.includes` accepts inline `contents`.** No need to
  write per-account git config files separately — `multi-account`
  uses `{ condition = "gitdir:…"; contents = { user = { … }; }; }`
  in `programs.git.includes`.
- **Cross-platform HM modules: `lib.mkMerge` with `lib.mkIf
  isDarwin`/`isLinux` branches.** `launchd.agents.<n>` and
  `systemd.user.{services,timers}.<n>` only exist on their
  respective platforms. The `mkIf` gating keeps the dormant branch
  from touching options that don't exist — same recipe used in
  `homeModules/{msgvault-sync,qmd-reindex}.nix`.
- **`writeShellApplication` adds `set -euo pipefail`.** Subprocess
  calls inside need `|| true` / `|| rc=1` to neutralize failures
  when you want best-effort semantics (see `gclb-sync`).
- **import-tree picks up every `*.nix` recursively.** You can't put
  "helper" nix files (non-flake-parts modules) under `new_modules/`
  without them getting imported as top-level flake-parts modules.
  Either put them outside `new_modules/`, prefix the dir with `_`,
  or have each file register a real flake-parts attribute.
- **`outputs = self` threaded via `mkSpecialArgs`.** Lets any HM /
  system module destructure `{ outputs, … }` and access
  `outputs.packages.<sys>.<name>`, `outputs.neusis.X`, etc. Used by
  the umbrella to grab `gclb`, by `bootstrap-repos` to reference
  `gclb`, and by anything else that needs a flake-defined package.
- **`git add -N` after creating new files.** Nix flakes evaluating
  from a git repo skip untracked files. `nix eval` returns mysterious
  "attribute missing" errors until you stage them. `git add -N` is
  the lightweight "make visible to flake eval" mode that doesn't
  stage content. Mentioned earlier in this doc — re-emphasising
  because it keeps biting.

### Open WIP gaps — updated status

From the previous list at the top of this file:

- ✅ **anklab references `self.neusis.machines.<host>` with no
  option** — closed by adding `machineType` + `flake.neusis.machines`.
- ✅ **Field-name inconsistency
  (`homeModules` vs `machineToBundleMap`)** — closed; rename to
  `machineToBundlesMap` (plural), one canonical name everywhere.
- ❌ **`initialHashedPassword` default** — still references
  `../secrets/common/hashedInitialPassword.age`. Untouched this
  session; callers continue to override.
- ❌ **Duplicate lab entries (`cslab.nix` +
  `cslab_karkinos.nix`)** — untouched. Still produces duplicated
  members in `registry.users.cslab`.

### Still open, deferred for a future session

- **`mkNeusisOS` + `mkNeusisDarwinOS` could collapse into a single
  `mkSystem "nixos"|"darwin"`.** Maybe 30 lines saved; passed for
  now because the branching read uglier than the duplication. See
  the bottom of `lib/neusisOS.nix` for the obvious factoring.
- **`roleSpecs` could be promoted to a `flake.neusis.roles`
  option.** Right now adding a fifth role means editing the lib;
  exposing it as a typed flake option lets consumers extend. Notes
  in `docs/future-considerations.md`.
- **`mkAdmin`/`mkRegular`/`mkGuest`/`mkLocked`** are now thin
  aliases over `mkUser`. Keep or drop? Aliases preserve the previous
  public API; if nothing outside this flake calls them, they can go.
- **gh CLI multi-account** isn't solved by `tools.multi-account`.
  `gh auth login` is single-host; this stays a manual `gh auth
  switch` dance until upstream gets multi-account support.
- **`features/darwin/system-defaults.nix`** still hardcodes
  `system.stateVersion = 5` and a bunch of macOS defaults that
  aren't per-machine. If a non-Apple-Silicon darwin host shows up,
  factor those out.
- **`homes/common/dev/{git,gclb}.{nix,py}`** still exist — port is
  done, but the originals haven't been deleted. Verify the new
  modules cover everything in real use before removing.
- **`flake.nix.bak`** is the pre-flake-file backup of the old root
  `flake.nix`. Useful as a reference for inputs that haven't been
  ported yet (e.g. `msgvault`, `llm-agents`, `nix-homebrew`,
  homebrew taps). Don't delete until the migration is complete.

### Process notes

- Several rounds of *test, surface a downstream error, fix it,
  re-test* this session — typical pattern was:
  `nix eval .#darwinConfigurations.rogue.config.<field>` → look at
  the bottom of `--show-trace` → fix → repeat. Bottom of the trace
  is the real error; everything above is module-system context.
- `nix run .#write-flake` is needed any time a `.nix` file under
  `new_modules/` adds a new `flake-file.inputs.<x>` entry. Forgot
  this once or twice; symptom is "input X missing" on the next
  eval.
- The Python rewriter (gclb) was the only place this session where
  we touched non-Nix code — `pkgs.writers.writePython3Bin` runs
  flake8 over the input. Keep the `# flake8: noqa` header on
  hand-rolled python files or accept that the nix build will fail
  on long lines / unused imports.
