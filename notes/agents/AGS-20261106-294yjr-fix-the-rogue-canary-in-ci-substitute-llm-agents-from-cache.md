---
id: AGS-20261106-294yjr
type: agent_session
schema_version: 1
title: "Fix the rogue canary in CI: substitute llm-agents from cache.numtide.com, cap the job at 120 min"
model: "claude-opus-5-5"
harness: "claude-code"
started: 2026-11-06T02:04+00:00
finished: 2026-11-06T02:10+00:00
created_entities: []
edited_entities: []
outcome: done             # done | failed | aborted | pending
created: 2026-11-06
author: agent:claude
---

## Task

ank asked to check the CI runs and investigate failures, then to apply both proposed fixes
without a review this time.

## What happened

All test jobs (T0–T3), ghost001, docs and kalam-zero-release were green. The pipeline was
red only on `system rogue (canary)`, last green on 2026-11-02. The runner substitutes from
cache.nixos.org alone, so it built the llm-agents packages (qmd, gemini-cli, opencode, pi)
from source, where the hosts pull them from cache.numtide.com. Three ways that broke:
qmd npm `.tgz` fetches stalled until the 6 h job limit (2026-11-04 and 2026-11-05),
gemini-cli 0.66.0's npm deps hash mismatched (`66754dc`), and a source fetch found no
mirror (`a13d1a8`). The 2026-11-04 qmd output is on cache.numtide.com and on neither
numtide.cachix.org nor cache.nixos.org. The other cancellations were superseded pushes
(`cancel-in-progress`) and runner capacity ("not acquired by Runner of type hosted").

Fix in `.github/workflows/gates.yml`, `system` job: `extra-substituters` /
`extra-trusted-public-keys` for cache.numtide.com in the installer's `extra-conf`, and
`timeout-minutes: 120`. Checked with actionlint; the effect shows on the next pipeline run.
