---
id: AGS-20261127-cthjec
type: agent_session
schema_version: 1
title: wire nitya's server (ghost001) and node (ank on rogue) from the nitya flake's modules
model: "claude-opus-5-5"
harness: "claude-code"
started: 2026-11-27T11:40+00:00
finished: 2026-11-27T12:20+00:00
created_entities: []
edited_entities: []
outcome: done             # done | failed | aborted | pending
created: 2026-11-27
author: agent:claude
---

## Task

From nitya's phase 1 item 7 (nitya's AGS-20261127-crjc71): wire the nitya flake's new
`nixosModules.server` into ghost001 and its `homeModules.node` into ank's home on rogue.
The owner commits and pushes neusis (comin deploys ghost001).

## What happened

- `features/nixos/nitya-server.nix`: the server with `nityaServerTsAuthKey` (anklab's
  leoank key) and `nityaDelegateKey` as credentials; ghost001 imports the module and the
  feature and defines both secrets (root's).
- `users/ank/nitya.nix`: the `nitya-node-rogue` bundle (`nitya-node-rogue` on leoank, the
  leoank key at ~/.config/nitya/leoank-authkey, the hourly audit check), in rogue's
  bundle list.
- Tests: `tests/features/nixos/nitya-server.test.nix`, `test-nitya-server` in ghost001's
  machine test, `test-nitya-node` in rogue's.
- Not done, the owner's: `modules/secrets/ank/nityaDelegateKey.age` (an `age-keygen`
  identity, through `agenix edit -i`) and `agenix rekey`; `nix flake update nitya` once
  nitya is pushed.
- Surprise: `neusis-test` evaluates `.` as a git flake, so untracked files and
  `--override-input` on `nix run` do not reach it; it ran from a copy without `.git`,
  with the override passed to nix-unit as well.
