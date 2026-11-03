# ADR-0007: Changes are verified on a T0–T3 ladder: nix-unit over a mirrored test tree, flake checks, and NixOS VM tests

Status: accepted
Date: 2026-10-06
Backfilled: 2026-11-03, from `testing.md` (§2, §3, §5, §7) and `porting.md` (2026-10-06
test suite and VM test entries).

## Context
Until October the only check was evaluating each host's `drvPath` by hand, and several
modules had never been evaluated on the platform they claimed to support. The design
surveyed how the Nix community tests (`testing.md` §2).

Runners considered (§3.3):
- `nix-unit` from nixpkgs, no new input (chosen).
- `nix-unit` as a flake input with its flake-parts module: puts T0 inside
  `nix flake check`, but the check derivation needs every flake input to evaluate
  offline.
- `lib.runTests` + `runCommand`: poor diffs, and it can't assert on thrown errors.
- namaka snapshots: catches any drift, but has to be re-blessed after every
  home-manager bump.

`nix-unit`'s `expectedError` mattered because the library is assertion-heavy.

## Decision
- **T0** `nix run .#neusis-test`: nix-unit tests in `modules/tests/`, which mirrors the
  live tree one to one. Tests evaluate through `flake.neusis.lib.tests`
  (`evalHm` / `evalDarwin` / `evalNixos`) and compare plain values, never derivations.
  A known bug is pinned with `expectedError` and a comment, never skipped.
- **T1** `nix flake check --no-build --all-systems`: `checks.<system>` carries every
  host, home and package, so this evaluates all of them.
- **T2** builds the same checks.
- **T3** NixOS VM tests (`checks.<linux>.vm-*`, `pkgs.testers.runNixOSTest`), run under
  KVM on spirit and oppy from a Mac and natively in CI.
- **T4** (manual) the read-only cloud `plan` and bootstrap smoke check.
- Home modules are tested by evaluation only; the real machines are the build tests.
  Every module change carries its test in the same commit.

## Consequences
- The first run found nine issues (`testing.md` §6), all fixed the same day.
- T0 isn't part of `nix flake check`. The nix-unit input can be added later without
  changing any test file.
- VM tests need KVM: the lab builders, or CI's ubuntu runners.
