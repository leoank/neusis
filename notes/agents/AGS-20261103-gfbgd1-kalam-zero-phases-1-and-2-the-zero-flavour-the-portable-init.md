---
id: AGS-20261103-gfbgd1
type: agent_session
schema_version: 1
title: "kalam-zero phases 1 and 2: the zero flavour, the portable init file, built-in fallbacks"
model: claude-opus-5-5
harness: claude-code
started: 2026-11-03T15:00+00:00
finished: 2026-11-03T15:13+00:00
created_entities: []
edited_entities: []
outcome: done             # done | failed | aborted | pending
created: 2026-11-03
author: agent:claude
---

## Task
kalam-zero phases 1 and 2 (ADR-0016): the zero flavour, the portable `kalam-zero-init`, and built-in fallbacks for the plugin shortcuts, each exercised headless.

## What happened
- `_flavors/zero`: base's `opts.nix` and `keymaps.nix` plus overrides (indent folds, `exrc` off, truecolor only when advertised, `timeoutlen` 800) and `zero.lua`, about 50 shortcuts on built-ins with version guards.
- `kalam.nix`: `kalam-zero-init` renders the config with the five options from [[RUN-20261103-g9nmnp]] and fails the build on any `/nix/store` path (713 lines, none).
- `modules/tests/packages/kalam/kalam-zero.test.nix`: two T0 tests, and two headless checks (with and without rg) that install the file under `NVIM_APPNAME=kalam` and run 91 checks.
- The first headless run failed one check: the buffer list offered the empty `[No Name]` buffer. Fixed in `zero.lua`, not the test.
- Checks: T0 319/319; both headless checks pass on aarch64-darwin, and the no-rg one on x86_64-linux (remote builder), all on nvim 0.12.4. T1 still stops at the existing darwin001 secret; the new outputs evaluate on both Linux systems.
