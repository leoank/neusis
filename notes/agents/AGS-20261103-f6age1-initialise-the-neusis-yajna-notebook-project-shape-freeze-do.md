---
id: AGS-20261103-f6age1
type: agent_session
schema_version: 1
title: initialise the neusis yajna notebook (project shape), freeze docs/porting.md, wire yajna into the dev shell
model: claude-opus-5-5
harness: claude-code
started: 2026-11-03T13:50+00:00
finished: 2026-11-03T13:54+00:00
created_entities: [PRJ-0001]
edited_entities: []
outcome: done             # done | failed | aborted | pending
created: 2026-11-03
author: agent:claude
---

## Task
Make neusis a project-shaped yajna notebook, as agreed with ank: namespace `neusis`, no
`[repos]`, the agent skill committed, yajna in the dev shell, and `docs/porting.md`
frozen in favour of ADRs, `docs/architecture.md` and this notebook.

## What happened
- Tried `yajna init project` on a copy of the repo first: it names the namespace after
  the directory, which in this bare-repo layout is `main`, so the real init passed
  `--namespace neusis`.
- Drafted [[PRJ-0001]] (Introduction, Progress, Open questions, Design, Lessons) from
  `AGENTS.md`, `docs/overview.md`, `docs/porting.md` and `docs/auto-update-spec.md`;
  the open Progress items and questions are for ank to confirm or prune.
- Seeded `docs/architecture.md` and recorded the switch itself as ADR-0001 in
  `docs/decisions/`; put a frozen notice at the top of `docs/porting.md`.
- Added a *Lab notebook (yajna)* section to `AGENTS.md` and pointed its references to
  the porting log at the notebook.
- Added `yajna` to `devShells.default` (the input already existed for ank's home) with a
  test in `modules/tests/features/flake/agenix-rekey.test.nix`.
- Checks: `yajna validate`, T0 317/317. T1 still stops at the darwin001 age secret that
  failed before this change.
