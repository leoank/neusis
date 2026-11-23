---
id: AGS-20261123-gy1eke
type: agent_session
schema_version: 1
title: "Nix GC on rogue stopped at a karabiner-dk store path: run the Karabiner driver daemon from a copy outside the store, keep nix-gc's output"
model: claude-opus-5-5
harness: claude-code
started: 2026-11-22T02:13+00:00
finished: 2026-11-23T14:39+00:00
created_entities: []
edited_entities: []
outcome: done             # done | failed | aborted | pending
created: 2026-11-23
author: agent:claude
---

## Task
ank: is nix garbage collection working on rogue? Then: keep the GC job's output, stage the
Karabiner driver daemon outside the store, commit and push.

Written on 2026-11-23 from the conversation's transcript, not during the session (the
session kept no page). Work was 2026-11-22 02:13–02:40Z, then the commit and push on
2026-11-23 at 14:37Z.

## What happened
- `launchctl print system/org.nixos.nix-gc`: `last exit code = 1` for the run at
  2026-11-22 00:00, and no output kept anywhere. Generations were being pruned and only
  ~0.2 GiB was dead, so collection had mostly worked until then.
- ank ran it by hand: 108 paths and 1.9 GiB went, then it stopped at
  `n3jjm…-karabiner-dk-6.2.0` with `fchmodat … Karabiner-VirtualHIDDevice-Daemon.app:
  Operation not permitted`, and macOS notified that kitty was prevented from modifying
  apps. The bundle carries `com.apple.macl`: macOS App Management locks a signed app
  bundle once it has run. The kanata module ran the driver daemon straight from the
  store, so every karabiner-dk build left a bundle nix can never delete, and nix aborts
  the whole collection at the first failure.
- 74d5c01 `fix(kanata)`: activation copies the daemon app to
  `/Library/Application Support/Nix-Karabiner/<driver store name>/` and launchd runs it
  from there; a folder per build so a locked copy is never overwritten, and old ones are
  removed best-effort with a warning. Test in `kanata.test.nix`.
- 79b13e5 `feat(nix-settings)`: darwin's `nix-gc` daemon writes stdout and stderr to
  `/var/log/nix-gc.log`. The first version merged with `//` on the module's top level,
  which recursed on `options`; it is a `config = lib.mkMerge [...]` now. Test in
  `nix-settings.test.nix`.
- Decided without asking: the per-build folder and the warn-don't-fail cleanup; leaving
  `nix-optimise` alone.
- T0 353/353; rogue's system evaluated; not built or switched (ank's to run). The two
  locked store copies (`n3jjm…`, and `i22j7…` once the switch retires it) need one GC from
  a terminal with App Management; until then the weekly GC still stops there.
- The commit rebased onto two CI input updates and carried another session's unpushed
  sandhi commits (cdb7eb4, 6a355d7) to `main`; ank's uncommitted saarthi bump was already
  in the bot's ee1c2e6. Only `main` was pushed.
- Not done the right way: no experiment before the change. The daemon running from a
  copy outside its upstream path was not tried before committing; it is still unverified
  until rogue switches. Led to the rule in [[AGS-20261123-gmpzpb]]'s follow-up: test
  important changes with an experiment first.
