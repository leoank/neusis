---
id: AGS-20261113-1ejvv4
type: agent_session
schema_version: 1
title: Bump anvesana for curiosity (sensor hub fixes) and build the curiosity-live ISO
model: "claude-opus-5-5"
harness: "claude-code"
started: 2026-11-13T01:19+00:00
finished: 2026-11-13T01:40+00:00
created_entities: []
edited_entities: []
outcome: done             # done | failed | aborted | pending
created: 2026-11-13
author: agent:claude
---

## Task

Ank asked to bump the anvesana input for curiosity (sensor hub fixes, anvesana 779cb82..ca3009c;
details in anvesana's AGS-20261112-szs9zf and EXP-20261113-0c42xp), build the `curiosity-live`
ISO on curiosity and leave it where Ank can write the stick from rogue.

## What happened

- The checkout was 4 commits behind origin/main; fast-forwarded before `nix flake update
  anvesana`. Committed and pushed the lock as 2e64a68 (Ank approved the push).
- T0 `nix run .#neusis-test`: 327/327. T1 `nix flake check --no-build --all-systems` fails on
  ghost001 (`path '...-ghost001' is not valid`, agenix-rekey) with the old anvesana pin too, so
  it is on main already and not from this bump; left for Ank.
- Built `.#curiosity-live` on curiosity itself (`--builders ''`, Ank asked for a local build;
  the kernel was already built from the same derivation). curiosity runs from the stick, so
  the stick is written from rogue, not from here.
- ISO: nixos-curiosity-26.05.20261108.ac588ef-aarch64-linux.iso, 8600487936 bytes, sha256
  0859c345914e08830905929a00de4215fc85e02bd39912148fdf6eb8a03f03b1. rogue refused SSH from
  curiosity and SPARKDATA is root-only, so Ank copies it to rogue with scp and writes it there.
