---
id: AGS-20261123-gmpzpb
type: agent_session
schema_version: 1
title: Check that rcodesign gives Nix-built binaries a stable designated requirement, before keeping darwin signing keys in agenix
model: claude-opus-5-5
harness: claude-code
started: 2026-11-23T15:09+00:00
finished: 2026-11-23T15:10+00:00
created_entities: [EXP-20261123-gmpz81, RUN-20261123-gmqqh7, REV-20261123-gmqq87]
edited_entities: [PRJ-0001]
outcome: done             # done | failed | aborted | pending
created: 2026-11-23
author: agent:claude
---

## Task
ank asked whether keeping the darwin code-signing keys as agenix secrets in neusis, for
kanata, saarthi's node and (it turned out) kitty, would work, then asked to check
rcodesign first, then whether that check was recorded in yajna. It was not: the first
probe was typed into a shell with no pages. This session records it.

## What happened
- Found the two scratch handoffs (`scratch/saarthi-stable-signing-handoff.md`,
  `scratch/kanata-stable-signing.md`); both leave open how a headless or root activation
  reaches a keychain. Found kitty is the home-manager build, ad-hoc signed, so it loses
  App Management on each rebuild for the same reason.
- Recommended (not decided by ank yet): agenix-held keys signed with `rcodesign` from PEM,
  a root-only key for kanata (a user-readable key could forge kanata's Input Monitoring),
  a separate home key for saarthi's node and kitty.
- The hand probe, then [[EXP-20261123-gmpz81]] with [[RUN-20261123-gmqqh7]], a script
  that repeats it with a fresh throwaway certificate pinned to flake.lock's nixpkgs:
  every success criterion met. Decided without asking: the experiment stays `active` with
  outcome null and the conclusion is proposed in the log, since a human writes it.
- Opened [[REV-20261123-gmqq87]] for the notebook changes; added Progress items
  'Stable signing 1–2' and an open question to [[PRJ-0001]].
- Not recorded: the earlier work of this conversation (the GC failure on karabiner-dk,
  the kanata daemon copy and the nix-gc log, commits 74d5c01 and 79b13e5) has no session
  page of its own.
