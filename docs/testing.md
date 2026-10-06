# Testing neusis — design and work scope

Status: **implemented** (2026-10-06): phases 0–6 of the work scope are
in; phase 7 is deferred. Section 6 lists what the suite found. Decisions
marked ✅ are final; section 5 records how each open question was settled.

Quick start:

```bash
nix run .#neusis-test                                 # T0, this system's test set (~1 min)
NEUSIS_TEST_SYSTEM=x86_64-linux nix run .#neusis-test # T0, the Linux set (from a Mac too)
nix run .#neusis-test -- --help                       # extra args go to nix-unit
nix flake check --no-build --all-systems              # T1 (~40 s)
nix build .#checks.aarch64-darwin.darwin-rogue        # T2, one check
```

## 1. Why

Today the only automated check in the flake is `check-flake-file` (is the
generated `flake.nix` in sync). Everything else is the manual "verification
ladder" in `AGENTS.md`: `nix eval` the two darwin hosts and two home configs,
then `nix build` them. That ladder has real gaps:

- **`mkNeusisOS` and every NixOS branch of the agnostic modules are never
  evaluated.** The live registry only has darwin hosts, so the `systemd`
  side of `tailscale`, `kanata`, `build-server`, `hm-system-init`, and the
  `initialHashedPassword` / role-group logic in `neusisOS.nix` have zero
  coverage. The `options ? launchd` / `options ? systemd` dispatch trick
  (porting log, 2026-08-16) is exactly the kind of thing that silently
  breaks on one platform.
- **Module behaviour is only tested through the two real machines.** An
  option that no machine sets (e.g. `brave.useHomebrew`, tailscale
  `forceHostName`, every disabled `tools.*`) is unexercised.
- **Upgrades surface as surprises.** The 26.05 bump found `gh-copilot`
  removed, `nodePackages` gone, yazi's wrapper renamed, nixvim option
  moves. Each was caught by hand-running the ladder and reading warnings.
- **The public API (`flakeModules.*`, `flake.neusis.lib.*`) has no
  consumer-side test.** `examples/` exists but nothing evaluates it.
- `stateVersion` policy ("never bump when bumping nixpkgs") is a
  convention in prose only.

## 2. How the Nix community tests

| Level | What it checks | Tools in use | Cost |
|---|---|---|---|
| **Pure eval unit tests** | Library functions, option defaults, assertion messages | `lib.runTests` (nixpkgs), **`nix-unit`** (nix-community), `namaka` (snapshots on top of nix-unit) | seconds |
| **Module eval tests** | Instantiate the module system with a tiny config, assert on `config.*` | `lib.evalModules` / `nixosSystem` / `darwinSystem` / `homeManagerConfiguration` + one of the above runners | seconds |
| **Module build tests** | Build the generated files and grep them | home-manager's `nmt` ("nix module tests": `assertFileExists`, `assertFileContent`); nix-darwin's `tests/*.nix` shell checks on `$out` | minutes, needs the closure |
| **Closure / build checks** | The whole system or home actually builds | `checks.<sys>.<name> = darwinConfigurations.x.system` so `nix flake check` covers it | minutes to hours |
| **VM integration tests** | Services really start, ports open, files land | `pkgs.testers.runNixOSTest` (NixOS only; needs KVM or a linux builder with the `nixos-test` feature) | minutes per test, Linux only |
| **Static checks** | Formatting, dead code, anti-patterns | `treefmt`, `nixfmt`, `statix`, `deadnix` | seconds |

Patterns worth copying:

- **nixpkgs** keeps `lib/tests/` as `lib.runTests` suites, run by a
  derivation that fails when the result list is non-empty.
- **home-manager** gives every module a `tests/modules/<name>/` directory
  with `*.nix` configs plus `nmt` assertions on the built `home-files`.
- **nix-darwin** builds a full system per test and greps the result.
- **Dendritic flakes** (mightyiam/infra, drupol/infra, vic/dendrix) co-locate
  a `checks` or `tests` flake-parts file next to the feature it tests,
  and let import-tree pick it up; `nix flake check` is the single entry
  point.
- **nix-unit** supports `expectedError = { type; msg; }` — the only runner
  that can assert on *thrown* errors and their messages. neusis's library
  is assertion-heavy (`mkNeusisOS` password guard, Darwin `nixpkgs`
  override guard, tailscale `defaultProfile`), so this matters.

## 3. Design

### 3.1 Four tiers, one entry point each

| Tier | Command | Runs in | Covers |
|---|---|---|---|
| **T0 eval unit** | `nix run .#neusis-test` (= `nix-unit --flake .#tests.<system>`) | ~65 s per test set (220 tests) | lib, options, every module and feature at eval level, machine invariants |
| **T1 eval flake** | `nix flake check --no-build --all-systems` | ~40 s | every `checks.*` derivation instantiates (= today's `drvPath` ladder, automated) |
| **T2 build** | `nix flake check` or `nix build .#checks.<sys>.<name>` | minutes–hours | systems, homes, packages really build |
| **T3 VM** (optional) | `nix build .#checks.<linux-sys>.vm-<name>` | minutes each | NixOS services under systemd; needs the linux-builder |

T0 is the default developer loop and the bulk of the new code. T1/T2 are
mostly glue: wrap what already exists as `checks`. T3 is proposed but
scoped out of the first pass (see open questions).

### 3.2 Where tests live ✅ mirror tree `modules/tests/**/<name>.test.nix`

Options considered:

| | Layout | Pros | Cons |
|---|---|---|---|
| A | `modules/homeModules/brave.test.nix` next to `brave.nix` | Dendritic-idiomatic; test is one `ls` away from its module | ~80 extra files interleaved in the tree |
| **B ✅** | Mirror tree `modules/tests/homeModules/brave.test.nix` | One place to look; the live tree stays uncluttered; still inside `modules/` so import-tree picks tests up with no wiring | Distance from code; two trees to keep in sync |
| C | Top-level `tests/` of plain Nix files (home-manager / nix-darwin style), one `modules/tests.nix` imports them | Familiar to nixpkgs people | Needs its own loader; loses the "every file is a flake-parts module" uniformity |

Chosen: **B**, keeping the `<name>.test.nix` suffix so a test file is
recognisable anywhere. The tree under `modules/tests/` mirrors the live
tree one to one:

```
modules/tests/
  harness.nix              flake.neusis.lib.tests + perSystem.tests option + neusis-test runner
  harness.test.nix         smoke tests for the harness itself
  _fixtures/               alice, lab registry, fixture machines, base modules (import-tree skips `_`)
  lib/neusisOS.test.nix
  agnosticModules/tailscale.test.nix
  homeModules/brave.test.nix
  homeModules/supercharged-git/gh.test.nix
  features/agnostic/nix-settings.test.nix
  machines/rogue.test.nix
  packages/checks.nix      checks.<sys>.pkg-* glue
  …
```

A test file is an ordinary flake-parts module. It never touches the
module's own output, only `perSystem.neusis.tests.*` (T0) and
`perSystem.checks.*` (T1/T2). `flakeModules.*` imports files by explicit
path, so test files never leak to consumers.

Fixtures (fake user, lab registry, fixture machines, minimal base modules
for HM / nix-darwin / NixOS) live in `modules/tests/_fixtures/` — `_` so
import-tree skips them; the harness imports them by path.

### 3.3 Runner ✅ nix-unit, no new flake input (initially)

| | Pros | Cons |
|---|---|---|
| **`nix-unit` from nixpkgs 26.05 (v2.34.2), plus a `perSystem.tests` option transposed to `flake.tests.<system>` and a `packages.neusis-test` wrapper (`nix run .#neusis-test`) ✅** | No new input; richest diffs; `expectedError`; `nix-unit --flake .#tests.x86_64-linux` from a Mac evaluates the Linux variants without building anything | T0 is not part of `nix flake check` |
| `inputs.nix-unit` + its flake-parts module | Adds `checks.nix-unit` so `nix flake check` runs T0 too | New input; the check derivation has to be handed *every* flake input (`nix-unit.inputs`) to evaluate offline — 22 inputs incl. homebrew-core; re-evaluates uncached in a sandbox |
| `lib.runTests` + `runCommand` | Zero tooling | Poor diffs; cannot assert thrown errors (only `tryEval`); the test *is* a derivation so iteration is slower |
| `namaka` snapshots | Catches any drift in generated files (would have flagged yazi `yy`→`y`) | Snapshot files to re-bless on every HM bump; noisy for a config repo |

We can add the nix-unit input later if we want T0 inside `nix flake
check`; nothing in the test files would change.

The runner is a package rather than a devShell entry because the devShell
is being moved to `modules/features/flake/shell.nix` in parallel work; add
`config.packages.neusis-test` to it once that lands.

### 3.4 Harness: `flake.neusis.lib.tests`

One file, `modules/tests/harness.nix`, exposes:

```nix
evalHm      { pkgs, modules }     # homeManagerConfiguration with alice fixture → config
evalDarwin  { modules }           # darwinSystem (aarch64-darwin) with minimal fixture → config
evalNixos   { system ? x86_64-linux, modules }  # nixosSystem with minimal fixture → config
failedAssertions cfg              # [] when every `assertions` entry holds
pkgNames    [ pkgs ]              # sorted unique package names of a package list
hasPkg      name [ pkgs ]
fixtures.{alice, lab, machines, builders, hmBase, darwinBase, nixosBase}
```

Tests receive `testPkgs` (perSystem `pkgs` with neusis's overlays applied
once per system, so `pkgs.unstable` / `pkgs.inputs.*` resolve as they do on
real hosts) and pass it to `evalHm`.

Two nix-unit facts shape the harness: it only runs attributes whose name
starts with `test` and silently ignores the rest (the `perSystem.tests`
option throws on any other name), and it evaluates on a thread with the
default stack, which segfaults on deep derivations such as `texliveFull`
(the `neusis-test` wrapper raises the stack to the hard limit first).

Each `eval*` injects the same `specialArgs` the real builders do
(`inputs`, `outputs = self`) so modules that take `outputs` work unchanged.

nix-unit compares plain values, so tests project `config` down to strings,
bools and lists (`pkgNames`, `config.home.file."x".text`,
`builtins.hasAttr`). Derivations are never compared directly.

### 3.5 What each layer gets

| Layer | Test kind | Examples |
|---|---|---|
| `lib/neusisOS.nix` | T0 unit + `expectedError` | `mergeUserConfigs` concatenates per role; `locked` plural regression; `mkNeusisFlake` names homes `alice@fixture`; missing `initialHashedPassword` throws the documented message; Darwin `nixpkgs` override throws; admin gets `wheel`, locked gets `nologin` + `hashedPassword = "!"`; HM wiring present iff registries non-empty |
| `lib/neusis-options.nix` | T0 | `hostname`/`username` default to the attr name; wrong types rejected |
| `agnosticModules/*` | T0 on **both** `evalDarwin` and `evalNixos` | tailscale: `launchd.daemons.neusis-tailscale-autoconnect` on Darwin, `systemd.services.…` with `Type = oneshot` on NixOS, neither leaks to the other; `defaultProfile` assertion; hm-system-init populates `home-manager.users.alice` from `machineToBundlesMap`; kanata / build-client / build-server / secrets likewise |
| `homeModules/*` (41 files) | T0 via `evalHm`, per file, Darwin + Linux pkgs | enable → expected packages and files; disabled → nothing leaks; each `tools.<x>` toggle; option passthrough (`brave.extraExtensions`, git `userName`); `failedAssertions == []` |
| `features/*` | T0 | `nix-settings` sets experimental features; `darwin.defaults` composes without conflicts; `distributed-builds` drops the local host from `nix.buildMachines` given the fixture builders registry; `mac-app-util` imports |
| `machines/*` | T0 invariants + T2 build | hostName / computerName / primaryUser; `home.stateVersion == "25.11"` and `system.stateVersion == 5` (encodes the "do not bump" policy); every registry user has an HM entry; `checks.aarch64-darwin.darwin-<host>` and `home-<user>@<host>` auto-generated from the registry |
| fixture NixOS machine | T0 | the only place `mkNeusisOS` runs end to end: users, groups, HM wiring, password guard |
| `packages/*` | T2 | `checks.<sys>.pkg-<name>` for kalam, kalam-full, gclb, neusis (`buildGoModule` runs `go test` in its check phase, so the CLI is covered by its build) |
| `flakeModules.*` | T0 consumer smoke | a nested `mkFlake` importing `self.flakeModules.default` the way `examples/flake-parts-consumer` does; asserts `flake.neusis.lib.neusisOS.mkNeusisFlake` exists and a one-machine registry produces `nixosConfigurations.fixture` |

### 3.6 Conventions

- Test file name: `modules/tests/<mirror path>/<module>.test.nix`. Each
  file owns one group, `tests.<layer>-<module>.test-<what>`, e.g.
  `tests.hm-brave.test-enable-installs-brave`. nix-unit only runs
  attributes whose name starts with `test`; the harness throws on any
  other name so a typo cannot silently drop a test.
- One `let cfg = evalHm {…}` per scenario; several asserts per scenario
  are fine, one scenario per behaviour.
- Platform-specific expectations go through `pkgs.stdenv.isDarwin` inside
  the test so the same file is valid under `tests.aarch64-darwin` and
  `tests.x86_64-linux`.
- No network, no IFD, no building in T0.
- A test that documents a known failure uses `expectedError` plus a
  `KNOWN BUG, pinned:` comment saying what to assert once fixed, never a
  skip.
- Project to plain values. Submodules fill in `null` siblings
  (launchd `KeepAlive`, `StartCalendarInterval`), DAGs wrap entries in
  `{ after; before; data; }` (`programs.ssh.matchBlocks`), home-manager
  normalises systemd unit values to lists and adds its own packages
  (`man-db`, session vars) and files (`opencode/opencode.json`), nix-darwin
  adds `activate-system` / `nix-daemon` daemons and `root` to
  `trusted-users`, nixpkgs appends `cache.nixos.org` — compare the fields
  you own, not whole attrsets.

## 4. Work scope

Implemented strictly one item at a time; each item ends with its tier
command green before the next starts. Commit per item
(`test(<scope>): …`).

| # | Item | Verify with |
|---|---|---|
| **Phase 0 — harness** | | |
| 0.1 | `modules/tests/harness.nix`: `flake.neusis.lib.tests`, `perSystem.tests` → `flake.tests`, `packages.neusis-test` runner; `modules/tests/_fixtures/`: alice, lab registry, fixture darwin + nixos machines, builders list, minimal base modules; `harness.test.nix` smoke tests | `nix run .#neusis-test` |
| **Phase 1 — lib** | | |
| 1.1 | `tests/lib/neusisOS.test.nix` | T0 |
| 1.2 | `tests/lib/neusis-options.test.nix` | T0 |
| 1.3 | `tests/lib/kalam.test.nix` (pure helpers only) | T0 |
| **Phase 2 — agnosticModules (both platforms)** | | |
| 2.1 | tailscale | T0 |
| 2.2 | hm-system-init | T0 |
| 2.3 | secrets | T0 |
| 2.4 | kanata | T0 |
| 2.5 | build-client, build-server | T0 |
| **Phase 3 — homeModules** | | |
| 3.1 | supercharged-git umbrella + 12 tool files | T0 |
| 3.2 | supercharged-shell umbrella + 9 tool files | T0 |
| 3.3 | terminal-velocity umbrella + 7 tool files | T0 |
| 3.4 | agent-harness | T0 |
| 3.5 | brave, brew-cask, claude-remote, hammerspoon, home-manager, mpd, qmd-reindex, rmpc, secrets | T0 |
| **Phase 4 — features** | | |
| 4.1 | agnostic: nix-settings, nix-pkgs, remote-access, distributed-builds, ank_mesh, cslab_mesh | T0 |
| 4.2 | darwin: system-defaults, nix-homebrew, theme, setup-keyboard, virtualization, defaults | T0 |
| 4.3 | hm: mac-app-util, setup-terminals | T0 |
| 4.4 | flake: agenix-rekey (devShell + rekey wiring present) | T0 |
| **Phase 5 — machines, packages, public API** | | |
| 5.1 | auto-generated `checks` for every darwin/nixos/home config | `nix flake check --no-build`, then `nix build .#checks.aarch64-darwin.darwin-rogue` |
| 5.2 | machine invariant tests (incl. stateVersion policy) | T0 |
| 5.3 | fixture NixOS machine through `mkNeusisFlake` (covered by `tests/lib/neusisOS.test.nix` and `tests/flakeModules.test.nix`) | T0 |
| 5.4 | `checks.pkg-*` for packages | T1, T2 |
| 5.5 | `flakeModules` consumer smoke | T0 |
| **Phase 6 — docs and automation** | | |
| 6.1 | `AGENTS.md` verification ladder → the four tiers; `docs/porting.md` entry | — |
| 6.2 | GitHub Actions `tests.yml`: T0 for `x86_64-linux` + T1 on ubuntu; T2 darwin builds optional on a macOS runner | workflow green |
| **Phase 7 — deferred** | | |
| 7.1 | VM tests: tailscale autoconnect, kanata, build-server on the linux-builder (explicitly skipped for now) | `nix build .#checks.aarch64-linux.vm-tailscale` |
| 7.2 | `nix-unit` flake input so T0 joins `nix flake check` | — |
| 7.3 | namaka snapshots for generated config files | — |

Size as implemented: 70 test files (220 tests), `harness.nix`, two checks
glue files, one fixtures directory, one CI workflow.

## 5. Decisions log

1. **Layout** — mirror tree `modules/tests/**/<name>.test.nix` (B), per
   Ankur's note on the draft.
2. **Runner** — nix-unit from nixpkgs, no new flake input; `nix run
   .#neusis-test` wrapper.
3. **Depth for homeModules** — eval-only; the two real machines plus the
   auto-generated `checks` are the build tests.
4. **VM tests** — skipped for now (Phase 7).
5. **CI** — yes, in this effort (Phase 6.2).

## 6. Findings (2026-10-06)

The first run of the suite found the issues below. All of them were fixed
the same day (commits on `main` after `27b0358`), and the tests that had
pinned them with `expectedError` now assert the fixed behaviour.

| Where | What the suite found | Resolution |
|---|---|---|
| `agnosticModules/kanata/kanata.nix` | Did not evaluate on NixOS: the Darwin block was gated with `lib.mkIf pkgs.stdenv.isDarwin`, which still registers `launchd` / `system.activationScripts.preActivation` on Linux; the Linux forwarding to `services.kanata` was commented out. | Dispatch on `options ? launchd` / `options ? systemd` like tailscale.nix; Linux forwarding restored and tested. |
| `agnosticModules/build-server.nix` | Did not evaluate on NixOS, even disabled: `users.knownUsers` (Darwin-only) under `mkIf pkgs.stdenv.isDarwin`. | Same dispatch; NixOS system user tested. |
| `homeModules/terminal-velocity/sesh.nix` | `tools.sesh` without `tools.tmux` tripped home-manager's `programs.fzf.tmux.enableShellIntegration` assertion. | sesh.nix sets it itself. |
| `homeModules/secrets.nix` | Importing without enabling failed: agenix-rekey's HM module asserts `age.rekey.masterIdentities` once loaded. | Import means enable: `enable` defaults to `true`; `false` is rejected with a neusis assertion. |
| `features/hm/setup-terminals.nix` | Read `./wezterm.lua`, `./gclb.py`, `./zellij*.kdl` that were never ported; unused since terminal-velocity. | Removed. |
| `registry/users/{all,cslab,cslab_karkinos}.nix` | Stale `self.registry` / `self.lib` / `self.users` paths; `cslab_karkinos.nix` defined `cslab` a second time; `all` omitted `kumaranklab`. | Paths fixed, karkinos has its own key, `all` merges every lab. |
| `packages/kalam` | `kalam-py` could not evaluate on Darwin (Wayland `badPlatforms`), breaking `nix flake check`. | `py` and `v2` flavours removed; `kalam` and `kalam-full` remain. |
| `homeModules/supercharged-git/multi-account.nix` | home-manager 26.05 deprecation warnings: `programs.ssh.matchBlocks` → `settings`, legacy `Host *` defaults. | Ported to `programs.ssh.settings`; `enableDefaultConfig = mkDefault false`. The suite now runs warning-free. |
| `examples/{external-flake,flake-parts-consumer}` | Used the pre-refactor API (`userConfig`, `homeManager`, `neusisOS.homeModules`, `self.flake.neusis`), referenced files that did not exist, and the flake-parts one imported `flakeModules.lib` which lacks the integration modules `mkNeusisOS` needs. | Rewritten against `userRegistries` / `machineToBundlesMap` / `flakeModules.default` with placeholder key and secret; both evaluate (`nix eval .#nixosConfigurations.myhost…` in each directory). |
