# ADR-0010: Cloud infrastructure is OpenTofu through the terranix flake-module, with Nix-pinned providers and encrypted state committed to git

Status: accepted
Date: 2026-10-16
Backfilled: 2026-11-03, from `cloud-terranix-spec.md` (§4.2, §6, §8, §12 questions 4
and 5).

## Context
Cloud machines on OCI (ghost001 first) needed their network, images and instances
declared from the same flake, with secrets kept out of the state. Alternatives in the
spec:
- Terraform instead of OpenTofu: works with terranix the same way, but has no native
  state encryption and an unfree licence.
- A hand-rolled `lib.terranixConfiguration` with its own apps: unnecessary, because the
  upstream flake-module provides `plan` / `apply` / `destroy`.
- An OCI Object Storage backend from day one: locking that one operator doesn't need,
  plus a bucket to bootstrap before any stack can store state.

## Decision
- OpenTofu (`pkgs.opentofu.withPlugins`), with providers from nixpkgs, so there are no
  registry downloads and provider versions move with the lock.
- Stacks go through the upstream terranix flake-module. `features/flake/terranix.nix`
  adds the neusis defaults in one place: the engine, the run-from-repo-root guard, and
  secrets loaded from `~/.config/neusis/tf.env` as `TF_VAR_*`.
- Reusable parts are `terranixModules/` (state encryption, `oci/*`, `cloudflare/*`).
  The fleet's stacks are `modules/infra/*`, with working dirs under `infra/<stack>/`.
- State is committed to git, encrypted with pbkdf2 + AES-GCM, with encryption enforced
  for both state and plan. The passphrase is an agenix home secret.

## Consequences
- History and rollback of infrastructure state come from git, and plaintext state can't
  be written.
- A second operator or CI applies would need a locking backend. The spec's migration
  path is the S3-compatible Object Storage backend, still with client-side encryption.
- `nix run .#<stack>.plan -- -detailed-exitcode` is the read-only drift check (T4).
