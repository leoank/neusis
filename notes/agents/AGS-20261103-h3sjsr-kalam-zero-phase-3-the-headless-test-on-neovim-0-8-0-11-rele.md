---
id: AGS-20261103-h3sjsr
type: agent_session
schema_version: 1
title: "kalam-zero phase 3: the headless test on Neovim 0.8-0.11 release builds"
model: claude-opus-5-5
harness: claude-code
started: 2026-11-03T15:34+00:00
finished: 2026-11-03T15:35+00:00
created_entities: [RUN-20261103-h3sjsx]
edited_entities: []
outcome: done             # done | failed | aborted | pending
created: 2026-11-03
author: agent:claude
---

## Task
kalam-zero phase 3: run the headless test on Neovim 0.8–0.11 (ADR-0016), in CI.

## What happened
- `_kalam-zero/neovim-releases.nix`: the official 0.8.3, 0.9.5, 0.10.4 and 0.11.7 x86_64-linux tarballs, pinned by hash and patched with autoPatchelfHook. The headless check now takes the Neovim to run.
- 0.8 first failed with no message: it ignores `NVIM_APPNAME`. The test now passes `-u` there, as ADR-0016 says to. It also now prints the startup messages when zero.lua doesn't load.
- [[RUN-20261103-h3sjsx]]: 97/97 on every version; no change to the file was needed.
- `tests.yml` T2 job builds the six x86_64-linux checks; `docs/testing.md` lists them.
- Proposed conclusion for [[EXP-20261103-g9kpxs]] (ank writes it): positive. nixvim emits the file with five options, and it runs, oil included, on every supported Neovim.
