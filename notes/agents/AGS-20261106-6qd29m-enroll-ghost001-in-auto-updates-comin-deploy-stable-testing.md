---
id: AGS-20261106-6qd29m
type: agent_session
schema_version: 1
title: Enroll ghost001 in auto-updates (comin, deploy/stable, testing-ghost001)
model: claude-opus-5-5
harness: claude-code
started: 2026-11-06T06:07+00:00
finished: null
created_entities: [REV-20261106-6qd2qd]
edited_entities: [PRJ-0001]
outcome: pending          # done | failed | aborted | pending
created: 2026-11-06
author: agent:claude
---

## Task

Add comin auto-updates to ghost001 like rogue's, with a testing branch, and enroll it now through `testing-ghost001`.

## What happened

- `modules/machines/ghost001.nix` imports comin, `nixosModules.auto-update` and the agnostic auto-update feature, and wires the `autoUpdateNotify` secret. ghost001 was already in the `stable` group, so comin follows `deploy/stable` (polled every 60 s) and its default testing branch `testing-ghost001`.
- `test-auto-update` in `ghost001.test.nix` pins the remote, both branches, the signers, the notify secret and the pre-switch check. T0 327/327 on both test sets; ghost001's toplevel evaluates after ank's `agenix rekey -a`.
- `docs/auto-update-guide.md` describes ghost001 as enrolled and its testing branch; a Progress item on the project page.
- Enrollment: push the commit to `testing-ghost001`, switch ghost001 once from it (built on ghost001), and keep the testing branch until `deploy/stable` contains the commit; otherwise comin would deploy a `deploy/stable` head without comin and remove itself.
