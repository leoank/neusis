# ADR-0009: The v1 tree is archived (v1 branch and tag, old_modules/ kept verbatim and buildable), not deleted

Status: accepted
Date: 2026-10-06
Backfilled: 2026-11-03, from `porting.md` (2026-10-06 *merge prep*) and
`old_modules/README.md`.

## Context
The dendritic tree (ADR-0002) was built under `new_modules/` on the `refactor` branch
next to the old layout, and was ready to land on `main`. The old tree still held
configuration not yet ported (machines, services, packages) and was the reference for
each port. Alternatives were not recorded.

## Decision
- A `v1` branch and an annotated `v1` tag capture `main` before the merge. The main
  worktree's uncommitted legacy edits were committed first, so the archive is complete.
- The whole old tree moves to `old_modules/` with `git mv`, so history follows. Its
  `flake.nix` and `flake.lock` are restored there, so it stays a self-contained flake
  (`nix build path:./old_modules#…`). `new_modules/` becomes `modules/`.
- `old_modules/` is never evaluated by the root flake. Nothing is ported from it
  silently: each port is logged (in `porting.md` until 2026-11-03, `yajna log` since).

## Consequences
- Every v1 blob is byte-identical under `old_modules/`, and v1 can still be built for
  comparison.
- The repo carries ~680 archived files, and greps across the repo hit them (exclude
  `old_modules`).
- `v1` names both a branch and a tag, so plain `git show v1:…` warns that the name is
  ambiguous; use `refs/heads/v1` or `refs/tags/v1`.
