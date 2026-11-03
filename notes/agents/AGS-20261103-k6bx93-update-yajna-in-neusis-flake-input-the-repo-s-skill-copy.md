---
id: AGS-20261103-k6bx93
type: agent_session
schema_version: 1
title: update yajna in neusis (flake input, the repo's skill copy)
model: claude-opus-5-5
harness: claude-code
started: 2026-11-03T17:28+00:00
finished: 2026-11-03T17:34+00:00
created_entities: [REV-20261103-k6bx64]
edited_entities: []
outcome: done             # done | failed | aborted | pending
created: 2026-11-03
author: agent:claude
---

## Task
Update the yajna plugin in neusis.

## What happened
- The Claude plugin isn't pinned in neusis: it's a marketplace with `autoUpdate` and was already on 0.17.0. The stale 0.5.0 skill I had loaded came from a cache older than this session's update.
- What neusis pins is the flake input (CLI, dev shell, yajna.nvim): bumped 0.19.0 → 0.22.1 and regenerated the repo's skill copy. Under [[REV-20261103-k6bx64]]; checks in its Summary.
