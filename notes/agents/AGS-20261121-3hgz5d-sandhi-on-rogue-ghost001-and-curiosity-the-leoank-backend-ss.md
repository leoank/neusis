---
id: AGS-20261121-3hgz5d
type: agent_session
schema_version: 1
title: "sandhi on rogue, ghost001 and curiosity: the leoank backend, ssh inward and through sandhi connect (sandhi phase 1.5)"
model: claude-opus-5-5
harness: claude-code
started: 2026-11-21T03:13+00:00
finished: null
created_entities: []
edited_entities: []
outcome: pending          # done | failed | aborted | pending
created: 2026-11-21
author: agent:claude
---

## Task
Wire sandhi (github:leoank/sandhi, ADR-0021) into the fleet, its phase 1.5
(sandhi PHS-20261121-07gk4r): the flake input, a home bundle per machine that puts
rogue, ghost001 and curiosity on leoank through sandhi with sshd published inward, the
leoank auth key as agenix secrets, and ssh's `ProxyCommand` for `*.leoank`.

## What happened
- `modules/users/ank/sandhi.nix`: `flake-file.inputs.sandhi` (nixpkgs-unstable and our
  yajna followed), the shared `sandhi` bundle (the sandhi flake's `homeModules.sandhi`,
  leoank with 22 -> 127.0.0.1:22, `~/.ssh/config.d/sandhi` with the `*.leoank`
  `ProxyCommand` by store path, `programs.ssh.includes`), and `sandhi-rogue`,
  `sandhi-ghost001`, `sandhi-curiosity` with the name and the key.
- The owner chose: an include file rather than moving rogue's hand-written ssh config into
  neusis (rogue adds `Include config.d/*` by hand); new secrets rekeyed by me; dutavas
  names that cannot clash with old leoank devices. I picked `sandhi-<host>`, after
  `saarthi-<host>`.
- Decided without asking: curiosity's dutavas is ephemeral (the live disk loses its state
  at every reboot) and starts after the agenix user unit; ghost001's key is a system secret
  owned by ank, as its saarthi tokens are.
- `agenix rekey -a` added only the three new rekeyed files. T0 353/353 on both test sets.
- Surprise: T1 failed with `path '…-ghost001' is not valid` for each freshly rekeyed
  directory, while HEAD passed; `nix eval` of a secret's `.file` put the directory in the
  store and T1 then passed. A local evaluation quirk of `--no-build`, not the config.
- Built rogue's home and the aarch64-linux sandhi (on curiosity as builder).
