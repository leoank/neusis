---
id: REV-20261106-6qd2qd
type: review
schema_version: 1
title: "Auto-updates on ghost001: comin on deploy/stable with testing-ghost001, enrolled through the testing branch"
project: null
target:
  kind: range               # branch | range | page | run | experiment | phase
  ref: HEAD..HEAD
base: c8319b98d18d9bc2a6ac3d04026c671425fa6049
head: f12664cd9c924bb5ff0ec4157df8098c230fcc88
rounds: [c8319b98d18d9bc2a6ac3d04026c671425fa6049]
paths: []
about: [PRJ-0001]
status: open              # open | changes_requested | approved | merged | closed
created: 2026-11-06
author: agent:claude
---

## Summary

ghost001 gets comin like rogue: `deploy/stable` (the stable group, a day behind canary) plus `testing-ghost001`, registry signers only, failure mail through `autoUpdateNotify`, and the pre-switch check. Enrolled through `testing-ghost001`, which has to stay at or ahead of f12664c until `deploy/stable` contains it. Checks: ghost001 toplevel evaluates, T0 327/327 on both sets.

## Threads
