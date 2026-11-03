# ADR-0012: Hosts update themselves with comin, deploying signed commits from deploy/<group> branches that CI fast-forwards after the gates pass

Status: accepted
Date: 2026-10-21
Backfilled: 2026-11-03, from `auto-update-spec.md` (§3, §4, §5, §6, §14) and
`porting.md` (auto-updates M1–M5).

## Context
Hosts were switched by hand, so they drifted, and nothing tested a lock bump before it
reached a machine. The tools surveyed (listed in the spec's first revision, in git
history):
- colmena: push-based, NixOS-only.
- deploy-rs: push-based.
- `system.autoUpgrade`: a NixOS-only timer.
- A hand-rolled timer.
- Cachix Deploy: paid.
- bento, morph, krops.

For commit signing, GitHub's web-flow key (which signs every web-UI and API commit) was
rejected as far too broad a trust root.

## Decision
- **comin** (pinned to v0.14.0, built from its own flake so the binary matches the
  module's schema) runs on NixOS and nix-darwin. It polls a branch, by default every
  60 s, and deploys only new commits whose head is SSH-signed by a key in the signers
  registry.
- **Branches:**
  - `main`: humans and the bot; nothing runs from it.
  - `auto/update-inputs`: the daily lock bump under test.
  - `deploy/<group>`: written only by the bot, fast-forward only.
  - `testing-<hostname>`: a comin trial deploy that lasts until reboot.
- **Groups** are registry entries: `canary` (rogue), and `stable` (ghost001) after
  canary plus a 24 h soak.
- **Signing:** humans sign with their own keys and CI with a dedicated bot key. comin
  and CI verify against the same `registry.signers`, and a change to the signers must be
  signed by a key that is currently trusted.
- **CI:** the daily bump lands on `main` only when every gate is green. Promotion to
  `deploy/*` follows the group order and soak, and failures raise an email and a
  rolling GitHub issue.

## Consequences
- Hosts pull, so there is no inbound deploy path, and an unsigned head (web-editor or
  GitHub-made merges) holds the group.
- Activation runs unattended, which exposed steps that need a human or a permission
  (macOS App Management, Homebrew upgrades; `porting.md` 2026-11-01).
- comin on darwin depends on nix-darwin's `activate-user` stub, which is due to be
  removed (risk R1).
