---
id: AGS-20261103-gzban7
type: agent_session
schema_version: 1
title: "kalam-zero: inline oil.nvim into the single file"
model: claude-opus-5-5
harness: claude-code
started: 2026-11-03T15:27+00:00
finished: 2026-11-03T15:27+00:00
created_entities: []
edited_entities: []
outcome: done             # done | failed | aborted | pending
created: 2026-11-03
author: agent:claude
---

## Task
Replace netrw in kalam-zero with oil.nvim, or something like it, without much extra work.

## What happened
- Writing an oil-like buffer meant reimplementing oil's rename, move and delete logic, so I inlined the real thing instead. kalam's oil 2.15 is 37 pure-Lua modules with its own checks down to nvim 0.8.
- `kalam.nix`: each module becomes a `package.preload` entry ahead of the config, with oil's MIT licence as a comment. The two syntax files go into a per-process temp dir on 'runtimepath' (`:finish` can't run through `vim.cmd`). It's the same derivation as base's oil. The file grew to 380 KB.
- `zero.lua`: oil with base's settings on `<leader>o`, `<leader>e` (float) and `-`; netrw only if `require("oil")` fails. The wrapped `kalam-zero` loads oil normally.
- Headless test: oil lists the directory, its syntax (ID concealing) loads, and an edited buffer creates a file. 97 checks pass with and without rg on nvim 0.12.4; T0 319/319.
- Recorded as ADR-0017, which amends ADR-0016's plugin-free file. Committed separately from phases 1 and 2 (`8100ee4`, verified at that rev).
