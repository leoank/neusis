---
id: AGS-20261111-p2qz0s
type: agent_session
schema_version: 1
title: Rewire neusis on the saarthi flake's hub and node modules, renaming rc2s2 everywhere
model: claude-opus-5-5
harness: claude-code
started: 2026-11-11T20:06+00:00
finished: 2026-11-11T20:06+00:00
created_entities: []
edited_entities: []
outcome: done             # done | failed | aborted | pending
created: 2026-11-11
author: agent:claude
---

## Task
The owner renamed rc2s2 to saarthi and moved its hub and node modules into the saarthi
flake as their source of truth (saarthi ADR-0041). Rewire neusis on them, with ghost001's
hub record migrated to the new directory before the switch, and rogue's files left to
home-manager and agenix.

## What happened
- Pulled main (68f99ad). The `saarthi` flake input replaces `rc2s2` (declared in
  `features/nixos/saarthi-hub.nix`, `flake.nix` regenerated, locked at saarthi 32fe5d0).
- Deleted `nixosModules/rc2s2-hub.nix`, `homeModules/rc2s2-node.nix` and their tests;
  ghost001 imports `inputs.saarthi.nixosModules.saarthi-hub`, ank's `saarthi-node`
  bundle imports `inputs.saarthi.homeModules.saarthi-node` (which also puts `saarthi`
  on PATH, so the bundle's `home.packages` line went). Options are `services.saarthi-*`.
- Secrets: the four `rc2s2*` sources and their four rekeyed copies were renamed
  `saarthi*` by `git mv`. agenix-rekey names a rekeyed file
  `<sha256(host pubkey hash + source content)>-<secret name>.age`
  (`nix/output-derivation.nix` in agenix-rekey), so with the content unchanged the
  renamed files are what `agenix rekey` would write; nothing was decrypted.
- ghost001: dataDir `/srv/saarthi`, user `saarthi-hub`, ntfy topic `saarthi`. The
  switch stops the removed `rc2s2-hub` unit before starting `saarthi-hub`, whose
  `ExecStartPre` (`+`, root) copies `/srv/rc2s2/hub.db*` into `/srv/saarthi` and chowns
  them, only when the new `hub.db` does not exist; `/srv/rc2s2` stays as a backup. The
  copy and its idempotence were simulated in a scratch directory.
- rogue: token files move to `~/.config/saarthi/` and the launchd agent becomes
  `saarthi-node`, both by home-manager and agenix at the switch. The sandbox profile's
  state dir is now `~/.local/state/saarthi/sandbox` and starts empty (not moved, as the
  owner asked).
- yajna's per-user `[repos]` key and the agent-harness option `tools.claude.rc2s2` are
  `saarthi`; tests and the agent-harness tutorial follow.
- Not run, at the owner's standing request: the neusis checks (T0-T2). Every changed
  file parses.
