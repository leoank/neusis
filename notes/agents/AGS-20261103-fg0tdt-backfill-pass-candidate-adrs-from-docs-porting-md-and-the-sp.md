---
id: AGS-20261103-fg0tdt
type: agent_session
schema_version: 1
title: "backfill pass: candidate ADRs from docs/porting.md and the specs"
model: claude-opus-5-5
harness: claude-code
started: 2026-11-03T14:06+00:00
finished: 2026-11-03T14:17+00:00
created_entities: []
edited_entities: []
outcome: done             # done | failed | aborted | pending
created: 2026-11-03
author: agent:claude
---

## Task
Propose which decisions from `docs/porting.md` and the specs deserve backfilled ADRs (ADR-0002 onward), with dates and sources, before any are written.

## What happened
- Read `porting.md` (the 2026-05-31 entry in full, the rest by decision language), the decision and alternatives sections of `cloud-terranix-spec.md`, `auto-update-spec.md` and `testing.md`, and dated the adoptions from git history.
- Proposed 12 candidates, 3 optional and 5 skips. ank chose the 12 plus attic and gave the dendritic rationale: v1 was already flake-parts but hand-wired (73 relative-path imports), and dendritic removed the plumbing.
- Wrote ADR-0002 to ADR-0014 in `docs/decisions/`, each dated when the decision was made and citing its source; "alternatives not recorded" where the record has none. Checked the facts against `testing.md` §6, the specs and git history, and corrected three drafts.
- Indexed them in `docs/decisions/README.md` and linked them from `docs/architecture.md`.
