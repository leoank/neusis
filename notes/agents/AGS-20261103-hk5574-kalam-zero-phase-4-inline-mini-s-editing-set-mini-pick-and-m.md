---
id: AGS-20261103-hk5574
type: agent_session
schema_version: 1
title: "kalam-zero phase 4: inline mini's editing set, mini.pick and mini.clue"
model: claude-opus-5-5
harness: claude-code
started: 2026-11-03T16:01+00:00
finished: 2026-11-03T16:05+00:00
created_entities: []
edited_entities: []
outcome: done             # done | failed | aborted | pending
created: 2026-11-03
author: agent:claude
---

## Task
Decide whether kalam-zero still needs the plugin bundle, then inline the plugins ank chose instead.

## What happened
- Measured kalam's pins:
  - mini.nvim 0.17 needs nvim 0.10, at 12–156 KB per single-file module;
  - which-key 3.17 needs 0.9.4, is 164 KB and has a `plugin/` dir;
  - snacks 2.31 needs 0.10 (parts 0.11.4), is 1.3 MB in 126 files, and has `plugin/` and `queries/`.

  The 380 KB file took ~15 ms to source. ank chose: no bundle; inline mini's editing set, pick and clue. Recorded as ADR-0018, superseding ADR-0016's bundle.
- `kalam.nix`: `inlinePlugin` takes a list of files, so it can pick modules out of mini.nvim (same derivation as base's).
- `zero.lua`, on 0.10+ only:
  - the editing modules with base's settings (surround on `gs…`), and mini.clue with base's leader groups;
  - the find/buffer/recent/help/grep shortcuts call mini.pick, and mini.pick also serves `vim.ui.select`;
  - `]d` stays zero's diagnostic jump.
- Tests:
  - mini is set up on 0.10+ and absent on 0.8/0.9;
  - its mappings exist, the picker shortcuts reach mini.pick (builtins stubbed), and `gsaiw)` and splitjoin edit real text.
- Results: 104 checks on 0.8.3 and 0.9.5, 121 on 0.10.4, 0.11.7 and 0.12.4 (with and without rg); T0 319/319. The file is 904 KB and sources in ~24–32 ms on 0.12.4.
