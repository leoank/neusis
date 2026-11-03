---
id: AGS-20261103-g9kpnf
type: agent_session
schema_version: 1
title: "kalam-zero: design and the nixvim portability spike"
model: claude-opus-5-5
harness: claude-code
started: 2026-11-03T14:50+00:00
finished: null
created_entities: [EXP-20261103-g9kpxs, RUN-20261103-g9nmnp]
edited_entities: []
outcome: pending          # done | failed | aborted | pending
created: 2026-11-03
author: agent:claude
---

## Task
Design kalam-zero, a kalam flavour usable without Nix on machines reached over ssh (including embedded), and test whether nixvim can generate it.

## What happened
- Surveyed kalam: 7 shortcuts in base's `keymaps.nix`, ~120 more spread across plugin modules.
- Laid out the tradeoffs: a plugin manager on the target, vendored plugins, built-ins only. ank chose Neovim 0.8+, a single file plus an optional vendored bundle, `NVIM_APPNAME=kalam`, and a rolling release.
- Spike [[RUN-20261103-g9nmnp]] for [[EXP-20261103-g9kpxs]]: five nixvim options make `initFile` portable on nvim 0.12.4.
- Recorded the design as ADR-0016, with its nav line on `gh-pages`.
