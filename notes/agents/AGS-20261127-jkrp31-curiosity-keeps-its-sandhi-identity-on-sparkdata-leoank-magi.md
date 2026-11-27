---
id: AGS-20261127-jkrp31
type: agent_session
schema_version: 1
title: curiosity keeps its sandhi identity on SPARKDATA; leoank MagicDNS domain; sandhi bumped
model: claude-opus-5-5
harness: claude-code
started: 2026-11-27T16:56+00:00
finished: null
created_entities: []
edited_entities: []
outcome: pending          # done | failed | aborted | pending
created: 2026-11-27
author: agent:claude
---

## Task
curiosity's sandhi dutavas took a new name at every live-disk boot (sandhi
EXP-20261127-hsprp3); keep its identity on SPARKDATA under the name `sandhi-curiosity`.
Add leoank's MagicDNS domain (`tail73031.ts.net`) to the sandhi backend, and bump sandhi
for its fix of the key race (sandhi ADR-0007).

## What happened
- sandhi EXP-20261127-j1rwdg first: a non-ephemeral dutavas resumes from its
  `tailscaled.state` alone, without a key; an ephemeral one did not.
- ADR-0023 (proposed): the initrd's host-key script also restores
  `config/curiosity/sandhi/leoank/tailscaled.state` from SPARKDATA to `/var/lib/sandhi-ank`;
  tmpfiles gives it to ank in sysinit; a path unit (and the save service once at boot and
  activation) writes it back; curiosity's sandhi uses that state directory, not ephemeral.
- Decided without asking: the restore lives in the existing initrd step (the only place
  ordered before every user session without pinning ank's uid); the identity already on
  curiosity moves by hand once rather than through migration code.
- `domains = [ "tail73031.ts.net" ]` on leoank, and that domain in the ssh include.
- `sandhi` bumped to eef36e5. The three `test-sandhi` cases pass (evaluated alone; the owner
  runs T0); T1 passes; rogue's home, curiosity's new units and the aarch64-linux sandhi build.
- Committed as four: `build(flake)` the sandhi bump, `feat(ank)` the domain (index versions
  holding only its hunks, since the tests mixed both), `feat(curiosity)` the persistence
  with ADR-0023, and these notes; T1 and the three `test-sandhi` cases on each staged tree.
  Another session's uncommitted kanata and signing work was left alone.

