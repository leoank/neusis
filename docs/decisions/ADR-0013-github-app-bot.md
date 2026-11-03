# ADR-0013: CI acts as a GitHub App, the only actor allowed to move deploy/*, rather than through a personal access token

Status: accepted
Date: 2026-10-21
Backfilled: 2026-11-03, from `auto-update-spec.md` (§10, §14) and `github-bot-setup.md`.

## Context
The pipelines of ADR-0012 push lock bumps and fast-forward the `deploy/*` branches, so
CI needs write access. The spec compared a GitHub App with a fine-grained PAT:
- **Identity:** the App is `neusis-auto-updates-ci-bot[bot]`; a PAT acts as ank.
- **Token life:** the App's is minted per run for an hour; a PAT is long-lived and
  rotated by hand.
- **Ruleset bypass:** the App can be the only actor allowed on `deploy/*`; with a PAT
  the bypass would be "ank", with no separation from his own pushes.
- **Leak impact:** an App token is short-lived and scoped to one repo; a PAT works until
  it expires, on whatever it covers.

## Decision
- One App, `neusis-auto-updates-ci-bot`, installed only on `leoank/neusis`, with
  Contents, Issues, Pull requests and Workflows write, and Actions read.
- Rulesets: `deploy/*` can be created or updated only by the App, with no force pushes
  or deletions. `main` allows no force pushes or deletions, and ank's direct pushes
  keep working.
- Commit signing is separate: a dedicated SSH key in the `auto-update` environment,
  listed in the signers registry.

## Consequences
- The App needs the Workflows permission even though it never edits a workflow, because
  GitHub refuses any App push that makes a branch carry workflow changes.
- Bot commits show *Unverified* on github.com (a bot user can't register SSH signing
  keys); comin verifies them against the registry regardless.
- Setup is an App plus `APP_ID` and `APP_PRIVATE_KEY`, documented in
  `github-bot-setup.md`.
