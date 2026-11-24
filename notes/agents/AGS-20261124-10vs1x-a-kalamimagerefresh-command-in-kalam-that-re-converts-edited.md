---
id: AGS-20261124-10vs1x
type: agent_session
schema_version: 1
title: A :KalamImageRefresh command in kalam that re-converts edited images (no keymap)
model: claude-opus-5-5
harness: claude-code
started: 2026-11-24T00:56+00:00
finished: 2026-11-24T01:03+00:00
created_entities: [EXP-20261124-10vsty, RUN-20261124-10vt37]
edited_entities: []
outcome: done             # done | failed | aborted | pending
created: 2026-11-24
author: agent:claude
---

## Task
ank: add the `:KalamImageRefresh` command offered earlier (no keymap), for images that
changed on disk but kept their old picture in kalam. Opened before the work.

## What happened
- The command rested on an unchecked reading of snacks.image, so [[EXP-20261124-10vsty]]
  first. [[RUN-20261124-10vt37]] (kalam headless, isolated cache): a PNG is used as is, a
  JPEG's cached conversion stays stale until deleted, and `image.clear()` gives fresh
  image objects. The first run tried only a PNG; the script was extended and re-run.
- Reading snacks further: `:edit` keeps `vim.b.snacks_image_attached`, so a document
  would not re-attach; the command re-places through the inline update (`BufWinEnter`)
  and `Snacks.image.buf.attach` for image buffers instead, and so works with unsaved
  changes.
- `userCommands.KalamImageRefresh` in `_flavors/base/config/plugins/snacks.nix`; test
  `modules/tests/packages/kalam/kalam.test.nix` (the command's steps and no keymap).
  Headless smoke test: the command exists and removes the cache. T0 354/354.
- Decided without asking: clear the whole snacks image cache rather than only the
  current buffer's images (conversions are rebuilt lazily on view); no review opened,
  since REV-20261123-gmqq87 is still open and the skill says to ask ank to finish it first.
- Open: the redraw in kitty is unverified; ank to check after the switch. Nothing committed.
