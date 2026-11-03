---
id: REV-20261103-k6bx64
type: review
schema_version: 1
title: "yajna 0.19 → 0.22: CLI, nvim plugin and the repo's skill copy"
project: PRJ-0001
target:
  kind: range               # branch | range | page | run | experiment | phase
  ref: HEAD..HEAD
base: 97eb6c26d0189f2eb0b7926d36e59a7d07b08a17
head: 2e82fcbda3c1abe4505a9a77b5c872321fab2b00
rounds: [97eb6c26d0189f2eb0b7926d36e59a7d07b08a17]
paths: []
about: [PRJ-0001]             # the pages it is about: experiments, runs, a project
status: open              # open | changes_requested | approved | merged | closed
created: 2026-11-03
author: agent:claude
---

## Summary
Brings the pinned yajna up to the plugin. The Claude plugin is declared in `modules/users/ank/ank.nix` (`extraKnownMarketplaces.yajna`, `autoUpdate = true`), so Claude Code updates it by itself; it is on 0.17.x. The flake input that pins the CLI, the dev shell's `yajna` and kalam's yajna.nvim was at 0.19.0 (`cd547aa`), three releases behind, and the plugin's skill already documented `yajna run record` and friends.

The commit:
- `nix flake update yajna` to `2c88d86` (0.22.1);
- `yajna skill` regenerated `.claude/skills/yajna/SKILL.md`, now the same text as the plugin's.

Checks: T0 319/319; `kalam` builds; `ank@rogue`, rogue's system and `ank@ghost001` evaluate; `yajna validate` passes on the notebook unchanged.

Not done: the new skill asks runs to record the full commit SHA, host, env and outputs (`yajna run record`). RUN-20261103-g9nmnp and RUN-20261103-h3sjsx predate it and keep short SHAs. They still validate.

## Threads
