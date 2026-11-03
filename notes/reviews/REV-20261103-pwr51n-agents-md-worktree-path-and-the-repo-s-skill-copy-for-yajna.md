---
id: REV-20261103-pwr51n
type: review
schema_version: 1
title: AGENTS.md worktree path and the repo's skill copy for yajna 0.24.1
project: PRJ-0001
target:
  kind: range               # branch | range | page | run | experiment | phase
  ref: HEAD..35de7668ca34ed52da63bdb029f8a4d2410a6860
base: 6e2128c3f3aa27cebedd48bcc66e054e699c9ed6
head: 35de7668ca34ed52da63bdb029f8a4d2410a6860
rounds: [6e2128c3f3aa27cebedd48bcc66e054e699c9ed6]
paths: []
about: [PRJ-0001]             # the pages it is about: experiments, runs, a project
status: approved          # open | changes_requested | approved | merged | closed
created: 2026-11-03
author: agent:claude
---

## Summary
Follows `6e2128c` (yajna 0.24.0 → 0.24.1).
- In a project repo, `yajna worktree` now names the directory by its topic alone: `yajna worktree --help` gives `<container>/<topic>`. `AGENTS.md`'s yajna section still said `../<branch>`, which with branch `neusis/<topic>` meant `../neusis/<topic>`.
- `35de766` rewrites the line: branch `neusis/<topic>`, checked out at `../<topic>` beside `main`.
- `yajna skill` under 0.24.1 regenerates `.claude/skills/yajna/SKILL.md` unchanged, so there is no skill commit. The Claude plugin updates itself from the marketplace after ank's switch.
- 2026-11-03 20:51 ank approved: Look good. Approved.

## Threads
