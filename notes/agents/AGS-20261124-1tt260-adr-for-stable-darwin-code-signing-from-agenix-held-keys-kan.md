---
id: AGS-20261124-1tt260
type: agent_session
schema_version: 1
title: ADR for stable darwin code signing from agenix-held keys (kanata, saarthi's node, kitty)
model: claude-opus-5-5
harness: claude-code
started: 2026-11-24T01:40+00:00
finished: 2026-11-24T01:41+00:00
created_entities: []
edited_entities: []
outcome: done             # done | failed | aborted | pending
created: 2026-11-24
author: agent:claude
---

## Task
ank asked whether the code signing works yet (it does not: only EXP-20261123-gmpz81 has
run) and then to start with the ADR. Opened before the writing.

## What happened
- `docs/decisions/ADR-0022-stable-darwin-code-signing-from-agenix-keys.md`, status
  proposed, and its README row. Rests on [[EXP-20261123-gmpz81]]; the work stays under
  [[REV-20261123-gmqq87]], which is about exactly this.
- Decided without asking (ank to confirm in the review): the key names
  (`neusis-codesign-system`, `neusis-codesign-ank`), the signed-copy paths under
  `Application Support/neusis/signed/<id>/`, identifiers `dev.leoank.{kanata,saarthi,kitty}`,
  warn-and-keep-the-previous-copy on failure, and the order kanata → saarthi → kitty.
- Left open in the ADR: how saarthi's node runs the signed copy (a saarthi module option, or
  a neusis package symlinking to it; the symlink needs an experiment), and kitty's bundle
  signing (an experiment first).
- Not updated: `docs/architecture.md`, until the design is accepted and built.
- Slip: the first write went to `~/workspace/hub/leoank/neusis/docs/` (the bare repo's
  parent) instead of the `main` worktree; the placeholder file and its empty directories
  were removed at once.
