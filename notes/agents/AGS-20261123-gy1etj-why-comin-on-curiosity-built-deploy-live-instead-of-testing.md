---
id: AGS-20261123-gy1etj
type: agent_session
schema_version: 1
title: Why comin on curiosity built deploy/live instead of testing-curiosity
model: claude-opus-5-5
harness: claude-code
started: 2026-11-21T12:29+00:00
finished: 2026-11-21T12:40+00:00
created_entities: []
edited_entities: []
outcome: done             # done | failed | aborted | pending
created: 2026-11-23
author: agent:claude
---

## Task
ank: "comin is complaining on curiosity and not deploying testing branch". Diagnosis
only; nothing was changed or pushed.

Written on 2026-11-23 from the conversation's transcript, not during the session (the
session kept no page); `finished` is approximate, the time of the last answer.

## What happened
- curiosity (live disk) had rebooted at ~12:20Z, so comin started from an empty
  `/var/lib/comin`. At 12:22 it fetched and began evaluating `testing-curiosity`
  (7e833bd); at 12:23:58 it saw `deploy/live` at 74cfc2c, the CI bot's input update pushed
  on top of 7e833bd right after ours, dropped the testing evaluation and built
  `deploy/live`.
- Cause: comin follows a testing branch only while it is on top of the main branch; all
  three `testing-*` were at 7e833bd, one commit behind `deploy/live`. The machine was
  still getting everything on the testing branch, plus the input update.
- Noise, not cause: one `lookup github.com: no such host` on the first poll after boot
  (DNS not up yet), and `fatal: Refusing to point HEAD outside of refs/` on each fetch,
  after which evaluation succeeded; its source was not found.
- Offered, not done: fast-forward the testing branches to main; or have the bot's
  workflow push its commit to `testing-*` too, so this stops recurring.
