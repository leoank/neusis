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

---

## 2026-06-16 — supercharged toolkit family + agent-harness + ports

Built three more home-manager umbrellas on top of last session's
schema, ported the remaining personal terminal config out of
`homes/ank/configs/`, added a cross-platform kanata module, and
made the long-running services opt-in. Each umbrella follows the
same shape settled on with `supercharged-git`: a single
`homeModules/<name>.nix` file imports a directory of tool
sub-modules, each registering `flake.homeModules.<name>-<tool>`
and exposing `neusis.<umbrella>.tools.<x>.enable` plus a small
handful of knobs.

### Umbrellas added

- **`supercharged-shell`** (`homeModules/supercharged-shell.nix` +
  9 sub-tools): yazi (bundled `max-preview` plugin), direnv, fzf,
  television, nix-search-tv, nix-your-shell, nix-init, zoxide,
  atuin. Umbrella `enable` installs the curated CLI bundle: `bat`,
  `bottom`, `chafa`, `comma`, `duf`, `eza`, `fd`, `gdu`, `htop`,
  `imagemagick`, `nix-output-monitor`, `ouch`, `rclone`,
  `ripgrep`, `unzip`, `wget`, `xclip` + toolchains (`cargo`,
  `clang`, `cmake`, `deno`, `gnumake`, `ninja`, `nodejs_22`,
  `python3`, `rustc`, `texliveFull`) + Lua (`lua51Packages.{lua,
  luarocks}`) + `sioyek` on Linux only. `extraPackages` extends
  without forking; bundle deliberately omits anything already
  owned elsewhere (lazygit lives in supercharged-git, fzf/yazi/
  zellij configurations come from their respective tool
  sub-modules).

- **`terminal-velocity`** (`homeModules/terminal-velocity.nix` + 7
  sub-tools): wezterm (bundled `wezterm.lua`), kitty
  (platform-aware `hide_window_decorations`: `titlebar-only` on
  Darwin, `yes` on Linux), zellij (bundled `config.kdl` +
  `layouts/default.kdl`, `default_mode = "locked"` so it nests
  cleanly), tmux (vim-tmux-navigator + resurrect + continuum +
  better-mouse-mode + tmux-toggle-popup; six prefix-bound popups
  for scratch shell / yazi / lazygit / rmpc / agent-deck /
  ipython; fzf-tmux integration auto-wired when
  `supercharged-shell.tools.fzf` is on), sesh (`tmuxKey = "s"` by
  default), mosh, eternal-terminal. No umbrella `enable` — each
  tool stands alone. Funny-name pun: "max speed of a falling
  object."

- **`agent-harness`** (`homeModules/agent-harness/agent-harness.nix`):
  single-file umbrella for LLM CLIs (`claude-code`, `opencode`,
  `gemini-cli`, `pi`, `hermes`). Umbrella `enable` ships extras
  (`agent-deck`, `beads`, `beads-viewer`, `spec-kit`, `skills`,
  `qmd`) and shared `AGENTS.md` / `agents` / `commands` /
  `skills` directories used by every enabled agent. Per-agent
  `tools.<x>.{enable, settings, extraPkgs}`. On Linux every
  agent is wrapped through `jail-nix` (common options:
  `network`, `time-zone`, `no-new-session`, `mount-cwd`;
  per-agent `readwrite (noescape "~/.<agent>")`; `commonPkgs`
  bundle in every jail). On Darwin the unwrapped packages are
  used (jail-nix is Linux-only). Bundled `skills/skill-creator/`
  with 18 files. New flake input: `jail-nix.url =
  "sourcehut:~alexdavid/jail.nix"`.

  MCP server configuration was added then removed at user request
  — "we will only use skills." The `pi-mcp-adapter` string inside
  `tools.pi.settings.packages` is left intact: it's pi's own
  package name, not an MCP server config. Override
  `tools.pi.settings.packages` if you also want pi to skip the
  adapter.

### Other ports

- **`packages/gclb/gclb.{nix,py}`** — `perSystem.packages.gclb`
  via `pkgs.writers.writePython3Bin`. Python rewritten to use
  `argparse.parse_known_args` so unknown flags pass through to
  `git clone`. Bundled into `supercharged-git` umbrella's
  `home.packages` via
  `outputs.packages.${pkgs.stdenv.hostPlatform.system}.gclb`.
  Earlier overlay-based draft was reverted at user request — the
  perSystem-package path is canonical.

- **`bootstrap-repos` got `extraGitArgs`** (per-repo + module
  global). Generated `gclb-sync` shell-quotes the merged list via
  `lib.escapeShellArgs (cfg.extraGitArgs ++ e.extraGitArgs)` and
  the helper `clone_repo` shifts the first two args and forwards
  `$@` to `gclb`, so users can pass arbitrary `git clone` flags
  (e.g. `--depth=1`, `--filter=blob:none`).

- **`agnosticModules/kanata/{kanata.nix, custom.kbd}`** — Mirrors
  nixpkgs's `services.kanata` option surface (`enable`, `package`,
  `keyboards.<name>.{devices, config, extraDefCfg, configFile,
  extraArgs, port}`). Linux forwards to `services.kanata`; Darwin
  sets up Karabiner-VirtualHIDDevice via
  `system.activationScripts.preActivation` + a base
  `launchd.daemons.Karabiner-DriverKit-VirtualHIDDevice-Daemon` +
  one `launchd.daemons.kanata-<name>` per declared keyboard.
  Default `keyboards.default.configFile = ./custom.kbd`.

- **`users/ank/zsh.nix`** — Registers
  `flake.neusis.users.ank.hmBundles.zsh` containing the full
  ported zsh config (vi-mode plugin, oh-my-zsh
  git/gh/globalias, aliases including `cat=bat`/`df=duf`/`ll=eza
  -lah --color-scale=all --hyperlink`, `nz`/`nx`/`nxp`/`nxpc`
  shell functions, `completionInit` cache-stable workaround,
  `lib.mkOrder 1000` zshConfig + `lib.mkOrder 1500` zshLateInit
  merged via `lib.mkMerge`). Wired per-host via
  `machineToBundlesMap.<host>`.

- **`homeModules/{msgvault-sync,qmd-reindex}.nix`** — Both
  switched to opt-in via `neusis.services.<n>.enable`.
  Configurable `package`, `launchdSchedule`,
  `systemdOnCalendar`, `logDir`. msgvault has `extraArgs`
  (default `["sync"]`); qmd has `subcommands` (default
  `["update" "embed"]`) joined with `&&` via `bash -c`. Both use
  `lib.getExe cfg.package` and `lib.escapeShellArgs`.

- **`homeModules/hammerspoon/{hammerspoon.nix, init.lua,
  Spoons/}`** — Ports `homes/ank/configs/hammerspoon/` into a
  Darwin-only opt-in module. Vendored `init.lua` + bundled
  `SpoonInstall`, `PaperWM`, and `ActiveSpace` spoons ride along
  next to the module. `neusis.hammerspoon.enable` symlinks the
  bundled directory into `~/.hammerspoon/` (hammerspoon's
  canonical location — legacy used `xdg.configFile."hammerspoon"`
  which resolved to `~/.config/hammerspoon`, the wrong path
  unless `MJConfigFile` was set; the new module fixes this).
  `configDir` swaps in a user-provided dir. Module does **not**
  install hammerspoon itself — that's a homebrew cask, noted in
  the tutorial. Sister tutorials' overlap tables gained a
  `hammerspoon` row.

### Tutorials added

`docs/{supercharged-shell,terminal-velocity,agent-harness}/tutorial.md`
— one per umbrella, mirroring the supercharged-git format:
numbered tool sections, "Putting it all together" example, and
an "Overlap with sister umbrellas" table that lists every tool
across all four umbrellas. Update all four tables in lockstep
when adding or moving tools between umbrellas.

After `graphite` was deleted by the user mid-session, the
supercharged-git tutorial needed §12→§11 / §13→§12 / §14→§13
renumbering plus three `(§N)` cross-references repointed. Worth
auditing whenever a tool sub-module is added or removed.

### Patterns confirmed / new

- **Cross-platform HM cookbook**: `lib.mkMerge` with `lib.mkIf
  pkgs.stdenv.isDarwin { launchd.agents.<n> = …; }` and `lib.mkIf
  pkgs.stdenv.isLinux { systemd.user.{services,timers}.<n> = …;
  }`. The `mkIf` gating keeps the dormant branch from touching
  options that don't exist — same recipe used in
  `homeModules/{msgvault-sync,qmd-reindex}.nix` and
  `agnosticModules/kanata/kanata.nix`.

- **Bundled data alongside modules**: `kanata/{kanata.nix,
  custom.kbd}`, `agent-harness/{agent-harness.nix, AGENTS.md,
  skills/, …}`, `terminal-velocity/{wezterm/wezterm.lua,
  zellij/{config.kdl,layout.kdl}}`,
  `supercharged-shell/yazi/{yazi.nix, yazi_img_max/init.lua}`.
  `import-tree` only picks up `*.nix`, so non-Nix data files
  alongside are inert.

- **`programs.git.settings.url.<alias>:.insteadOf` as a list**
  serializes to multiple `insteadOf = …` lines — that's how
  `multi-account` redirects every `org/` per SSH alias without
  generating per-account include files.

- **`programs.git.includes` `contents` form** lets the
  multi-account module avoid materializing per-account git config
  files on disk — config lives inline in the includes attrset.

- **jail-nix `mount-cwd` is the agent escape hatch.** It's the
  only thing letting jailed agent CLIs see your code. Without it
  every agent is a paperweight. Per-agent `readwrite (noescape
  "~/.<dir>")` covers state; everything else outside `cwd` is
  opaque.

- **`programs.delta` standalone** replaces the legacy
  `programs.git.delta.*` settings. The new module sets delta as
  the diff pager via its own activation; double-check nothing
  else is trying to set `core.pager` separately.

- **`writeShellApplication` + `set -euo pipefail`** — anything
  intended to be best-effort needs `|| true` / `|| rc=1`. The
  bootstrap-repos `gclb-sync` script uses this for its
  per-repo loop so a single repo failure doesn't abort the rest.

- **Section renumbering rots silently.** When tools are deleted
  mid-tutorial, neither markdown linters nor `nix flake check`
  catch the dangling `(§N)` cross-references. Treat any
  sub-module addition/removal as a tutorial audit trigger.

### Open WIP gaps — status this session

From the running list at the top of this doc:

- ✅ **`mkNeusisDarwinOS` broken / `darwin` input missing** —
  closed previous session; verified end-to-end this session
  by evaluating `darwinConfigurations.rogue.config`.
- ❌ **`initialHashedPassword` default** — still references
  `../secrets/common/hashedInitialPassword.age`. Untouched.
- ❌ **Duplicate `cslab` registry entries** — untouched.
- ❌ **`mkSystem "nixos"|"darwin"` unification** — deferred again.
- ❌ **`roleSpecs` → typed `flake.neusis.roles` option** —
  deferred; notes still in `docs/future-considerations.md`.
- ❌ **`mkAdmin`/`mkRegular`/`mkGuest`/`mkLocked` aliases vs
  `mkUser`-only API** — alias layer kept; no consumer audit done
  to confirm callers.

### Still open after this session

- **Legacy `homes/common/dev/{git,gclb,editors,terminals}.nix`
  and `homes/ank/configs/{terminal/{tmux,zsh}.nix,
  keyboard/kanata_system.nix, agent_harness/}`** still on disk
  despite their content being ported. Verify on a real
  `home-manager switch` before deleting.
- **`inputs.llm-agents.homeManagerModules`** not explicitly
  imported by the agent-harness umbrella — relying on upstream
  auto-injection into the HM context. If "option doesn't exist"
  errors fire on switch, add an explicit `imports = [
  inputs.llm-agents.homeManagerModules.default ]` somewhere
  upstream.
- **Agent-harness MCP**: the option block + config branch are
  gone, but `tools.pi.settings.packages` still lists
  `pi-mcp-adapter`. Override at the bundle if you want pi to
  skip loading it.

### Process notes

- `nix run .#write-flake` after every new `flake-file.inputs.<x>`
  entry. This session added `jail-nix`; running the regenerator
  was needed before `nix eval` would resolve it.
- Verification command for parse-only sanity on a new module:
  `nix eval .#homeModules.<name> --apply "x: builtins.typeOf x"`.
  Returns `"set"` if the module body itself parses; doesn't
  fully evaluate the config, but catches the obvious nix-syntax
  / option-typo class of errors before the slower
  `home-manager.users.<u>.imports = […]` round-trip.
- The MCP-removal pass touched four files (the module, the
  agent-harness tutorial, and two sister-umbrella overlap
  tables). When ripping a feature out, grep for the feature
  name across `docs/` and across all umbrella tutorials — the
  overlap tables are the easiest to miss.

---

## 2026-06-17 — kalam family + nvim-debug skill + rogue feature parity

The session-of-many-sessions. Three threads landed: the kalam
nixvim distribution got a proper library layer plus a clean
`base` flavor written from scratch, an `nvim-debug` skill encodes
the diagnostic patterns we developed while debugging dap, and
rogue's home-manager bundle list reached feature parity with the
legacy `homes/ank/machines/rogue.nix` (stylix, brave, atuin,
tmux, mpd, rmpc — all now declarative through `flake.neusis`).

### kalam: library + variant builder + flavor scaffold

- **`flake.neusis.lib.kalam`** (`new_modules/lib/kalam.nix`) —
  new lib namespace. `mkKalamVariants { pkgs; inputs; outputs;
  root }` enumerates subdirs under `root`; subdir name `base` →
  package `kalam`, anything else → `kalam-<name>`. `mkKalam`
  builds a single flavor from a directory containing `config/`
  and (optional) `lib/`. Per-flavor `lib/` is honoured if
  present; helpers `icons`, `mkPlugin`, `whichkeySpec`,
  `mkKeymap` live in the shared namespace and propagate via
  `extraSpecialArgs` as `kalamLib`. Legacy aliases (`icons`,
  `mkPkgs`, `specObj`) are preserved at the top level of
  `extraSpecialArgs` so unported flavor modules keep working.

- **Flavors relocated** to `new_modules/packages/kalam/_flavors/{base,py,v2}/`.
  The `_flavors/` prefix keeps `import-tree` from interpreting
  the ~208 nixvim config modules as flake-parts modules — same
  trick as `_kalam/` for the shared icons data, hammerspoon's
  `Spoons/`, and the agent-harness `skills/skill-creator/`
  subtree.

- **Per-flavor `default.nix` derivation files deleted.** The
  shared `mkKalam` does the build. Per-flavor `lib/` directories
  also deleted (they were identical across flavors and the
  shared lib now provides the helpers).

- **Removed per-package nixpkgs rebuild.** Legacy
  `pkgs/kalam{,py,v2}/default.nix` each did
  `import inputs.nixpkgs { cudaSupport = true; overlays = [ … ]; }`
  inside the derivation — forcing a full nixpkgs rebuild per
  flavor and baking CUDA in. New `mkKalam` uses the perSystem
  `pkgs` verbatim; the perSystem driver `pkgs.extend self.outputs.overlays.git-worktree`
  for the one overlay the configs actually need
  (`pkgs.git-worktree-custom`). CUDA dropped.

- **New flake input** `nixvim = "github:nix-community/nixvim/nixos-25.11"`
  declared in `new_modules/packages/kalam/kalam.nix` via
  `flake-file.inputs`.

- **Old `pkgs/` tree no longer wired in.** `flakeModules/packages.nix`
  (the legacy flake-parts module that imported `../pkgs`) was
  deleted. `outputs.packages.<system>` now exposes
  `kalam`, `kalam-py`, `kalam-v2`, `gclb` — no more `kalamv2`,
  `specstory`, `xrt`, `kexec_tailscale`. (Source files at `pkgs/`
  still on disk; deletion deferred until non-kalam consumers
  are confirmed unused.)

### kalam-base: clean implementation from scratch

Built on three toolkits per a deliberate philosophy choice:

- **blink.cmp** — single completion engine (LSP + path + snippets
  + buffer sources). Uses `lspkind`'s symbol_map for richer kind
  icons.
- **mini.nvim** — pairs, comment, surround, move, bracketed,
  splitjoin, hipatterns, bufremove, sessions, icons. **`mini.ai`
  removed** — raced with treesitter-textobjects on `af`/`ac`/`aa`,
  winner depended on typing speed. treesitter-textobjects + vim
  defaults cover the same surface area.
- **snacks.nvim** — bigfile, quickfile, dashboard (custom
  giraffe ASCII art), indent + scope, input, notifier, picker
  (replaces telescope), rename, scratch, statuscolumn, terminal
  (replaces toggleterm), toggle, words, zen, image. Most of the
  `<leader>` map dispatches to snacks features.

Plus catppuccin (theme, with `integrations.dap` for dap highlight
groups), treesitter + treesitter-context + treesitter-textobjects,
nixd + pyright (LSP), conform.nvim (format-on-save with
`vim.g.disable_autoformat` toggle), gitsigns, lualine (now with
filesize component), bufferline, oil + yazi (replaces
snacks.explorer), leap (bidirectional `s`, cross-window `S`),
trouble, undotree, colorizer, dap + dap-view + dap-python +
dap-virtual-text.

`mini.surround` was rebound from `s*` to `gs*` so leap could own
single-key `s`. Parallel mnemonic with `gc` (comment) and `gS`
(splitjoin).

`<leader>` map labelled groups: `b` (buffer), `c` (code), `d`
(debug), `dP` (python-debug), `f` (find/file), `g` (git), `gh`
(hunks), `q` (quit/session), `s` (search), `t` (terminal/tab),
`u` (toggles), `w` (window proxy → `<c-w>`), `x` (trouble), `z`
(zen), plus non-leader `gs` (surround).

### nvim-debug: lessons codified into a skill

Six different bugs across the kalam debug session each demanded
the same diagnostic pattern — write a Lua script that probes
state and writes results to `/tmp/diag.log`, run nvim
`--headless -c 'lua dofile(...)' -c 'qa!' <test-file>`, read the
log from the shell. Encoded as `~/.claude/skills/nvim-debug/`:

- The `--headless -c 'lua dofile(...)'` pattern (NOT `nvim -l`,
  which skips startup).
- Probe cookbook: module load state, LSP clients/settings/
  capabilities, keymaps via `maparg`, signs (with the group
  scope gotcha — `sign_getplaced { group = "*" }` doesn't always
  match), autocmds via `nvim_get_autocmds`.
- Locating the generated init.lua in nixvim:
  `grep -oE '/nix/store/[a-z0-9]+-init\.lua' $PKG/bin/nvim`.
- `xxd` on string options to verify multi-byte glyphs survived
  the source → emission pipeline (see "burned hours" below).

Packaged via `package_skill.py` into `~/Downloads/nvim-debug.skill`
for portable install.

Ran description optimization via `run_loop.py` (5 iterations).
**No improvement found** — all iterations scored 50% with
recall=0%. Root cause is a structural limit of the optimization
loop (Claude's headless skill-consultation heuristic doesn't
respond to description tweaks on debugging-style queries; it
decides "I'd just inspect files directly"). Best = original
description by tiebreak. Documented as a known limitation.

### Burned hours rediscovered (six bugs, each illuminating)

These each cost time and each taught something worth remembering:

1. **Nerd-font PUA glyphs got stripped to empty strings** in the
   nix source itself. The bytes between `text = "..."` quotes
   were `22 22` (just the quotes). Diagnosed via `xxd` after the
   sign_define output showed no `text` field. Fix: replace with
   BMP characters (`●`, `◆`, `◌`, `→`) which have well-defined
   UTF-8 encodings and survive every copy/paste/serialize chain.
2. **nvim's native `'exrc'` option doesn't fire on a kalam
   launch** despite `opts.exrc = true` + matching trust hash.
   Suspect: nixvim's `-u <init.lua>` wrapper interaction. Worked
   around with a `VimEnter` autocmd in `autocmds.nix` that
   manually does `vim.secure.read` + `loadstring` + invoke.
   Native exrc remains an unsolved mystery; the manual loader
   is the working substitute.
3. **dap.adapters.python showing `<function1>`** — dap-python's
   setup runs after our manual table-form adapter registration
   and replaces it with a function-form adapter that misbehaves
   on nix store paths. Reordered: pcall dap-python.setup FIRST,
   then our `dap.adapters.python = { type = "executable"; … }`
   wins. Followed by a final pass that moved everything to
   nixvim's native `plugins.dap-view.settings.auto_toggle` /
   `plugins.dap.signs` so the extraConfigLua block could be
   dropped entirely.
4. **`claude-remote.nix` in `homeModules/` had no
   `flake.homeModules.<name>` wrapper.** `import-tree` picked it
   up as a top-level flake-parts module; its body's
   `launchd.user.agents.X = ...` got applied at the wrong
   evaluation context, where `pkgs` wasn't a module arg. This
   broke darwin options tree evaluation entirely, which silently
   blanked nixd's hover/gd against `services.X`. Rewrote as a
   proper `flake.homeModules.claude-remote` with
   `neusis.claude-remote.enable`, `profile`, `projectDir`,
   `claudeBin`, `logDir` options. Also switched from nix-darwin's
   `launchd.user.agents` namespace to home-manager's
   `launchd.agents` since the module lives under `homeModules/`.
5. **lspconfig deprecation warning** every launch — fixed by
   mutating `lspconfig.configs.nixd.default_config.settings`
   directly in the `.nvim.lua` exrc rather than calling
   `lspconfig.nixd.setup({...})`. Same effect, no warning. Uses
   lspconfig internals so brittle, but works until nixvim
   migrates to `vim.lsp.config`.
6. **nixd needs manual submodule descent** for flake-parts
   options. `evaluated.options.flake` is a typed option, not a
   walkable attrset. The `.nvim.lua` exrc descends via
   `evaluated.options.flake.type.getSubOptions []` and wraps as
   `{ flake = <subopts>; }` so user-typed paths like
   `flake.neusis.users.X.hmBundles.Y` walk through the tree.
   Also declared `flake.homeModules` and `flake.darwinModules`
   as typed options in `neusis-options.nix` — flake-parts itself
   only declares `nixosModules`, so without these `nixd` couldn't
   complete `flake.homeModules.<TAB>`.

### Other ports landed today

- **mpd + rmpc** as `homeModules` (`new_modules/homeModules/{mpd,rmpc}.nix`).
  mpd module is platform-aware: default log file at
  `~/Library/Logs/mpd/log.txt` on Darwin, `~/.local/state/mpd/log`
  on Linux. Activation script creates log dir + touches log file
  + creates playlist dir. rmpc takes structured options
  (`address`, `volumeStep`, `maxFps`) that get substituted into
  a default RON config; full `config` string also overridable.

- **kanata** as `agnosticModules/kanata/kanata.nix`. Mirrors
  nixpkgs `services.kanata` option surface; Linux forwards to
  `services.kanata`, Darwin sets up Karabiner-VirtualHIDDevice
  via `system.activationScripts.preActivation` + launchd daemons.

- **stylix** as `users/ank/theming.nix` hmBundle. Iosevka Term
  Nerd Font Mono, evenok-dark base16 scheme, terminal opacity
  0.8, wallpaper at `users/ank/_assets/wallpaper.jpg` (copied
  from `homes/common/gui/wallpapers/gruvbox_astro.jpg`). New
  `flake-file.inputs.stylix = "github:danth/stylix/release-25.11"`.

- **brave** as `homeModules/brave.nix`. Wraps `programs.chromium`
  with `pkgs.brave` + ublock origin / dark reader / kagi search /
  theme extensions. `useHomebrew` opt lets Darwin users prefer
  the cask (module then only writes preferences/extensions, cask
  owns the binary). Bundle wiring in `users/ank/ank.nix` as
  `hmBundles.browsers`.

- **zsh polish**: `users/ank/zsh.nix` gained `history.path =
  "${config.xdg.dataHome}/zsh/history"`, `history.size = 10000`,
  and the `update <host>` / `darwin <host>` shell helper
  functions for `nixos-rebuild` / `darwin-rebuild` invocations.

### rogue feature parity

After porting the missing pieces, `darwinConfigurations.rogue`'s
home-manager bundle list now reads:

```
machineToBundlesMap.rogue = [
  features.agnostic.nix-pkgs
  hmBundles.kalam-ide       # → kalam base (was kalamv2)
  hmBundles.terminal-life   # supercharged-git/shell/terminal-velocity + zsh
  hmBundles.agent-harness   # claude/opencode/gemini/pi/hermes + msgvault + qmd
  hmBundles.darwin-tools    # hammerspoon + mpd + rmpc
  hmBundles.theming         # stylix + iosevka + wallpaper
  hmBundles.browsers        # brave
  ./_packages.nix           # ank's home.packages list
]
```

The legacy `homes/ank/machines/rogue.nix` import chain has been
fully migrated. Items intentionally dropped: `programs.starship`
(was already `enable = false`), `programs.mcp` (user decided to
"only use skills" earlier; `pi-mcp-adapter` left in pi's
settings.packages as pi's own client-side package). gh-dash
extension on gh kept disabled by user.

### Patterns confirmed / new

- **`_flavors/` and `_assets/` prefix for non-module data.**
  Same as `_kalam/` for shared icons. import-tree skips any path
  containing `/_`. Use for: nixvim flavor configs (208 .nix
  files under `_flavors/`), wallpaper image, kanata custom.kbd,
  agent-harness skill-creator bundle (18 files).

- **nixpkgs.expr in nixd settings is project-agnostic; option
  trees are project-specific.** Base `lsp.nix` ships only
  `nixd.nixpkgs.expr = "import <nixpkgs> { }"` and
  `nixd.formatting.command = [ "nixfmt" ]`. Per-flake
  `options.<key>.expr` belongs in `.nvim.lua` exrc at the
  project root — neusis ships its own at the repo root.

- **`flake.homeModules.<name>` registration is mandatory** for
  any `homeModules/X.nix` file. Without it, `import-tree`
  applies the file's body as a top-level flake-parts module,
  silently breaking either the file's intent or downstream
  evaluation. The pattern is: `{ ... }: { flake.homeModules.X =
  { config, lib, pkgs, ... }: { options.neusis.X = …; config =
  lib.mkIf cfg.enable { … }; }; }`.

- **Catppuccin's `integrations.dap = true`** auto-defines the
  `DapBreakpoint*` highlight groups — no need for manual
  `vim.api.nvim_set_hl` calls when catppuccin is the
  colorscheme.

- **`nvim --headless -c 'lua dofile(...)' -c 'qa!'`** is the
  canonical pattern for inspecting plugin state from outside.
  `-l <script>` is a different mode that skips startup; useless
  for debugging user config.

### Still open

- **Legacy `pkgs/` tree** still on disk (kalam/kalampy/kalamv2
  + non-nvim packages: xilinx, intel-fpgas, nvidia_vgpu,
  specstory, sst, typedb, kexec_tailscale). Nothing in the
  active layout references it after the `flakeModules/packages.nix`
  deletion. Sweep candidate.
- **`flakeModules/`** directory (legacy flake-parts modules) is
  no longer loaded by the root flake (`flake.nix` only imports
  `./new_modules`). Deletion safe; deferred for archaeology.
- **`homes/`** likewise — all per-host content has been ported.
  Deletion needs verification that nothing references
  `homes/common/...` paths.
- **nixd native exrc** still doesn't load on a kalam launch
  (only via `--cmd 'set exrc'`). Workaround autocmd in
  `autocmds.nix` makes it work; root cause unidentified.
- **MCP server config** is gone from agent-harness. The
  `pi-mcp-adapter` entry in pi's `settings.packages` still
  ships — pi's own client-side adapter, not a server config.
  Override `tools.pi.settings.packages` to drop if you also
  want pi to skip the adapter.

---

## 2026-06-17 (cont.) — git workflow, theme tuning, commit split, build fixes

Second half of 2026-06-17. Kalam-base's git surface got rebuilt
top-to-bottom, the diff theme tuned through several feedback
rounds, the whole staged tree split into atomic commits, and two
regressions caught (one mine, one upstream-rename).

### Kalam-base: full git workflow rewrite

Replaced the single `<leader>gg` lazygit shortcut with four
purpose-built tools, each owning a clean slice of the surface
(see [`docs/kalam/git-workflow.md`](./kalam/git-workflow.md) for
the worked-example walkthrough):

| Plugin       | Owns                                                     | Prefix       |
| ------------ | -------------------------------------------------------- | ------------ |
| `gitsigns`   | gutter signs + hunk ops + inline rich view               | `<leader>gh` |
| `neogit`     | magit-style status/commit/merge/push/rebase popups       | `<leader>g…` (top-level) |
| `diffview`   | side-by-side diffs + file-history walking                | `<leader>gd` |
| `octo`       | GitHub issues/PRs/reviews/comments — shells out to `gh`  | `<leader>go` |
| `worktrees`  | create/delete/switch worktrees (afonsofrancof's, not the more-common ThePrimeagen) | `<leader>gw` |

Specifics worth remembering:

- **neogit** uses `kind = "tab"` (full-tab status), `integrations.diffview = true` so `d` inside the status buffer opens diffview, and `integrations.snacks = true` for native input/select prompts.
- **diffview** has no built-in toggle — wrote `_G.kalam_diffview_toggle` that introspects `diffview.lib.get_current_view()` for close-if-open / open-otherwise on `<leader>gdd`. The big-value binding turned out to be `<leader>gdf` = `DiffviewFileHistory %` — the canonical "when did this function break?" walk.
- **octo** with `picker = "snacks"` reuses the same picker UX as `<leader>ff`, so PR/issue lists feel native. `gh` bundled via `extraPackages`; user authenticates once with `gh auth login`.
- **worktrees.nvim isn't in nixpkgs** — inlined `pkgs.vimUtils.buildVimPlugin` directly in the plugin module (no overlay) with a pinned rev. `lib.fakeHash` first build → capture real hash from FOD mismatch → paste. The flake-prefetch hash and the FOD hash match exactly (`nix flake prefetch` uses the same NAR computation as `fetchFromGitHub`).
- **catppuccin integrations** extended: `diffview`, `neogit`, `octo` added so plugin-specific highlight groups get sensible bases from the theme.

Catppuccin's `gh auth status` requirement bites on first use only;
the bindings are wired regardless.

### Kalam-base: gitsigns rich view + UI toggles

Added three gitsigns settings (all default OFF) behind a snacks
toggle bundle:

- `linehl` — tints the whole changed line so it pops in context
- `word_diff` — highlights bytes that actually changed
- `toggle_deleted` (runtime) — renders deleted lines as virt-text in place; the answer to "I added 5 lines but what did I delete?"

Two snacks toggles wired inside a `VimEnter` autocmd (so both
snacks + gitsigns are loaded):

| Key            | What                                                                  |
| -------------- | --------------------------------------------------------------------- |
| `<leader>ug`   | git inline diff — flips linehl + word_diff + toggle_deleted bundle    |
| `<leader>ub`   | git inline blame — flips `current_line_blame`                         |

Initial bindings used `uG` / `uB` (inherited from a stale comment
in the previous gitsigns config); renamed lowercase to match the
rest of the `<leader>u*` cluster (only uppercase when the lowercase
letter is already taken: `uD` dim because `d` = diagnostics).

### Kalam-base: terminal `<Esc>` fix for zsh-vi-mode

User's zsh-vi-mode plugin consumes `<Esc>` inside `:te` terminals,
so the standard "press Esc to go to nvim normal mode" didn't work.
Snacks's toggle-terminal solves this with a buffer-local
`<Esc><Esc>` → `<C-\><C-n>`; mirrored at `mode = "t"` globally in
`keymaps.nix` (with `nowait = true` for responsiveness). Single
Esc still passes to the shell, double-tap returns to nvim normal.

### Kalam-base: diff theme — high-contrast iteration

Multi-round tuning driven by user feedback. The final palette
lives in `theme.nix` under `highlightOverride`:

| Group                          | Final value                            | Why                                                       |
| ------------------------------ | -------------------------------------- | --------------------------------------------------------- |
| `DiffAdd`                      | `bg=#1f3826`                          | dark forest green; less saturated than initial `#2e4d2f`  |
| `DiffChange`                   | `bg=#2c3e5b`                          | muted blue, distinct from DiffAdd                         |
| `DiffDelete`                   | `bg=#552e2e fg=#8a4a4a`               | solid red, dim fg                                          |
| `DiffText`                     | `bg=#4d7a2c fg=#f0f0f0 bold`          | clear step-up from DiffAdd; bold + light fg for byte legibility |
| `DiffviewDiffDelete`           | matches `DiffDelete`                   | initial fg-only override stripped the red bg — fixed       |
| `GitSignsDeleteVirtLn`         | `bg=#552e2e fg=#c87878`               | catppuccin sets fg-only; explicit bg restores deleted-row visibility |
| `GitSignsDeleteVirtLnInLine`   | `bg=#7a3a3a fg=#f0c8c8`               | brighter red for word-diff within virt deleted lines       |
| `GitSignsAddInline`            | `bg=#3a6020 fg=#f0f0f0 bold`          | the bytes that actually changed *within* an added line     |
| `GitSignsChangeInline`         | `bg=#3e5a8a fg=#f0f0f0 bold`          | likewise for changed lines — the "ur" in "ankur" pops      |
| `GitSignsDeleteInline`         | `bg=#7a3a3a fg=#f0c8c8 bold`          | inline highlight on deleted virt-line bytes                |
| `DiffviewFilePanelInsertions`  | `fg=#6fa84f bold`                     | toned-down green for sidebar `+N`                          |
| `DiffviewFilePanelDeletions`   | `fg=#e07070 bold`                     | balanced red for sidebar `-N`                              |
| `DiffviewDim1`                 | `fg=#6a6f80`                          | nudged up from default; unchanged context stays legible    |

### Diff highlight learnings

- **Catppuccin's gitsigns integration sets `GitSignsAddInline` / `GitSignsChangeInline` / `GitSignsDeleteInline` fg-only.** Without an explicit `bg`, the word-diff overlay vanishes into the surrounding `DiffAdd`/`DiffChange` tint. Override via `highlightOverride` so it re-fires on `ColorScheme` events.
- **`DiffText` overlays `DiffAdd`** — its `bg` must be a clear step-up from `DiffAdd.bg`, or the changed bytes look identical to the surrounding line.
- **Override `bg` AND `fg` together**, never just one. `DiffviewDiffDelete = { fg = "#5a5a5a" }` (fg-only) silently strips the red bg because no explicit `bg` means "inherit transparent" in this context.
- **`bold` is the subtle-but-visible win** for focal-point groups (`DiffText`, `GitSignsChangeInline`, etc.) — a dim bg + bold light fg lifts the bytes off without the neon look saturated bg gives.
- **Diagnosing**: `:hi <Group>` in a real diff buffer tells you exactly which palette is in effect post-catppuccin-integration. The first guess is rarely the active group; for `<leader>uG` rich view, it's the `GitSigns*Inline` groups, NOT `DiffText`.

### Commit hygiene — 22 commits, one logical change each

The full session's staged work was sliced into atomic commits
keyed to a single subsystem:

```
1. feat(kalam): port kalam family with new base flavor and lib
2. feat(hm-agent-harness): add agent-harness home-manager module with skills
3. feat(hm-brave): add brave browser home-manager module with curated extensions
4. feat(hm-claude-remote): add claude-remote launchd/systemd agent module
5. feat(hm-hammerspoon): add hammerspoon module with PaperWM + ActiveSpace spoons
6. feat(hm-mpd): add mpd home-manager module with platform-aware log paths
7. feat(hm-rmpc): add rmpc home-manager module with structured config knobs
8. refactor(hm-msgvault-sync): switch to options-based opt-in
9. refactor(hm-qmd-reindex): switch to options-based opt-in with subcommand list
10. refactor(hm-supercharged-git): drop graphite, extend bootstrap + delta
11. feat(hm-supercharged-shell): add shell utilities umbrella module
12. feat(hm-terminal-velocity): add terminal + multiplexer umbrella module
13. chore: ignore __pycache__ and *.pyc
14. fix(gclb): pass-through arbitrary git-clone args via parse_known_args
15. feat(lib): declare flake.homeModules and flake.darwinModules options   (later reverted)
16. chore: regenerate flake with nixvim, stylix, jail-nix inputs
17. feat(users-ank): wire kalam, theming, terminal-life on rogue
18. feat: add project-local nvim exrc for nixd against this flake
19. docs(agents): point agents at docs/ during refactor
20. docs(porting): append 2026-06-17 checkpoint
21. fix(lib): drop duplicate flake.homeModules and flake.darwinModules   (reverts #15)
22. fix(hm-supercharged-git): migrate aliases to programs.git.settings.alias
```

Pattern for "commit only X" with many staged paths and mixed
intent-to-add markers:

```bash
git add <X paths>                  # ensures content (not just names) is staged
git commit -m "..." -- <X paths>   # commits ONLY matching paths from index
```

Files that show ` A` in `git status --short` (space then A) are
intent-to-add — names registered, contents not actually staged.
A plain `git diff --staged` won't show them; you must `git add`
again (without `-N`) to register their contents.

### Regression caught: flake.homeModules duplicate declaration

Commit 15 above (`8d8f000`) added typed `flake.homeModules` and
`flake.darwinModules` options to `new_modules/lib/neusis-options.nix`
because nixd wasn't completing those paths in the kalam project
exrc. That declaration collides with home-manager's own flake-parts
module (and nix-darwin's) which ALREADY declare them when those
inputs are loaded.

`nix build .#kalam` evaluated fine (no home-manager pulled in)
but `darwinConfigurations.rogue.system` failed:

```
error: The option `flake.homeModules' in `…/neusis-options.nix' is
already declared in `…/home-manager/flake-module.nix'.
```

Fix (`6082d68`): remove the local declarations. nixd completion is
unaffected because `.nvim.lua` targets
`darwinConfigurations.rogue.options`, which transitively pulls in
both flake-modules. **Comment left in the file** documenting the
constraint so we don't re-add.

Takeaway pattern: **before declaring a flake-parts option locally,
grep the inputs**. flake-parts has multiple owners for the same
attribute name when nix-darwin + home-manager + nixos are all in
play.

### Regression caught: programs.git.aliases rename warning

Single trace warning during darwin build:

```
trace: warning: ank profile: The option `programs.git.aliases' …
has been renamed to `programs.git.settings.alias'.
```

home-manager moved the path. Migrated in `commitizen.nix`
(`05f0b7e`). Old name still works but emits the trace on every
`darwin-rebuild switch`.

To surface trace warnings reliably:

```bash
nix build .#darwinConfigurations.rogue.system --no-link --option eval-cache false 2>&1 | grep -iE "warning|deprecat"
```

The eval-cache reuses results across runs and silences traces on
the second invocation. `--option eval-cache false` forces re-eval.

### Other small wins

- **`docs/kalam/git-workflow.md`** (~370 lines) — worked-example
  walkthrough of the whole git surface: daily commit, selective
  hunk staging, history walking, merge conflict resolution, PR
  review, PR creation, issue triage, full bindings cheat sheet,
  five-pain-point troubleshooting.
- **`.gitignore`** now excludes `__pycache__/` and `*.pyc` — the
  `scripts/` agent-harness tree's incidental python caches no
  longer show in `git status`.
- **`gclb`** (the bare-clone helper) now passes unrecognised flags
  through to `git clone` via `parse_known_args`, so `gclb url
  --depth 1 --filter=blob:none` works without us mirroring every
  git-clone option.

### Patterns confirmed (new this session)

- **Snacks.toggle.new + VimEnter autocmd** is the cleanest way to
  register a custom toggle that integrates with which-key — defer
  the `Snacks.toggle.new({...}):map("<leader>X")` call until
  VimEnter so snacks + the underlying plugin (gitsigns here) are
  both ready. `pcall(require, "gitsigns")` inside the setter
  gives a clean no-op if it isn't.
- **`extraConfigLua` for plugin-bridging helpers** is preferable
  to scattering small Lua snippets across keymaps. The smart
  diffview toggle + gitsigns toggle bundles live together in
  `git.nix`'s extraConfigLua, surfaced via keymaps that call
  `_G.kalam_*` or via the `:map(key)` chain.
- **Inline `buildVimPlugin` is fine for one-flavor unpackaged
  plugins** — overlay only when multiple flavors share it (as
  `git-worktree-custom` does across py + v2).
- **`git commit -- <pathspecs>`** commits only matching index
  changes — even when other paths are staged. Use it to slice a
  busy staging area into clean atomic commits without `git reset
  HEAD` gymnastics.

### Still open after this session

- Native nvim exrc still doesn't fire on kalam launch (workaround
  via `kalam_exrc` autocmd in `autocmds.nix`).
- Legacy `pkgs/`, `flakeModules/`, `homes/` directories still on
  disk pending verification before deletion.
- The 22-commit branch hasn't been merged to `main` yet — pending
  user review of the splits.
