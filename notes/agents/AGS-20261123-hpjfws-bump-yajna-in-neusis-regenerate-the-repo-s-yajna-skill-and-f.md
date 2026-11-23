---
id: AGS-20261123-hpjfws
type: agent_session
schema_version: 1
title: Bump yajna in neusis, regenerate the repo's yajna skill, and fix the saarthi pin in the yajna machine config
model: claude-opus-5-5
harness: claude-code
started: 2026-11-23T16:06+00:00
finished: 2026-11-23T16:13+00:00
created_entities: []
edited_entities: []
outcome: done             # done | failed | aborted | pending
created: 2026-11-23
author: agent:claude
---

## Task
ank: after pushing the global-instructions change, bump yajna in neusis (and regenerate the
repo's skill copy, which was older than the yajna repo's) and fix the saarthi pin in the
yajna machine config, which `yajna repos` showed as missing. Opened before the work.

## What happened
- saarthi moved to a gclb worktree, `~/workspace/repos/leoank/saarthi/main` (has
  `yajna.toml`; `bootstrap-repos` already clones it under `~/workspace/repos`). Pin and the
  rogue test repointed: 1147897.
- `nix flake update yajna`: 82c6efe (2026-11-21) → d35a617 (2026-11-23), yajna 0.43.3. An
  earlier note in this conversation said d02aa69; that was another lock node.
- `.claude/skills/yajna/SKILL.md` regenerated with `yajna skill` from 0.43.3 (not the
  0.41.1 on PATH): it now has phases, `yajna data`, codified protocols and `@ work`
  threads. Bump and skill in one commit, since the skill is generated from the input.
- Checks: T0 353/353; rogue's darwin system and `ank@rogue` home evaluate; `yajna
  validate` clean apart from this page while open. Not built or switched.
- Not fixed, outside neusis: sandhi's `yajna.toml` still lists saarthi at
  `../../../../hub/leoank/saarthi`.
