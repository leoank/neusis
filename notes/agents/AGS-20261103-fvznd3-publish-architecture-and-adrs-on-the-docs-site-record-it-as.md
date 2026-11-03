---
id: AGS-20261103-fvznd3
type: agent_session
schema_version: 1
title: publish architecture and ADRs on the docs site; record it as ADR-0015
model: claude-opus-5-5
harness: claude-code
started: 2026-11-03T14:26+00:00
finished: 2026-11-03T14:27+00:00
created_entities: []
edited_entities: []
outcome: done             # done | failed | aborted | pending
created: 2026-11-03
author: agent:claude
---

## Task
Make the docs site (the `gh-pages` branch) publish `docs/architecture.md` and the ADRs, and record that as an ADR.

## What happened
- `gh-pages`: `nav.md` lists *Architecture*, *Decisions* and ADR-0001 to ADR-0015 under *Development*; `gen/render/upstream.py` turns `[[ID]]` into GitHub links via each notebook page's `id:` and points `README.md` links at `index.md` (mdBook rendered them as dead `README.html`); one sentence in `src/contributing/docs-site.md`.
- `main`: ADR-0015 records it and amends ADR-0001's plain-text-links consequence.
- Checks: `nix build .#site --override-input neusis path:../main` succeeds, and a scan of every relative link in the imported pages finds none broken.
