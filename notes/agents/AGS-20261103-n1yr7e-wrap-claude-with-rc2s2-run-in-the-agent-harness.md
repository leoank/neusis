---
id: AGS-20261103-n1yr7e
type: agent_session
schema_version: 1
title: wrap claude with rc2s2 run in the agent harness
model: claude-opus-5-5
harness: claude-code
started: 2026-11-03T19:10+00:00
finished: 2026-11-03T19:19+00:00
created_entities: [REV-20261103-n1yg3x]
edited_entities: []
outcome: done             # done | failed | aborted | pending
created: 2026-11-03
author: agent:claude
---

## Task
Wrap claude with `rc2s2 run` in the agent harness.

## What happened
- Read rc2s2's docs:
  - `rc2s2 run` gives a PTY the daemon can interrupt and kill;
  - with no daemon the session still works;
  - it clears `CLAUDE*` env vars.

  Read home-manager's claude-code module, which wraps `package` with `--plugin-dir`.
- Opened [[REV-20261103-n1yg3x]] before changing anything. One commit, `706a999`; details and checks are in the review's Summary.
- Decision: wrap only at a terminal. A PTY in a pipe would mix stderr into `claude -p` output.
