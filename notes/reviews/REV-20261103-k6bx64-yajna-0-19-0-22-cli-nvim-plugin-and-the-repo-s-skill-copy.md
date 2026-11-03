---
id: REV-20261103-k6bx64
type: review
schema_version: 1
title: "yajna 0.19 → 0.22: CLI, nvim plugin and the repo's skill copy"
project: PRJ-0001
target:
  kind: range               # branch | range | page | run | experiment | phase
  ref: HEAD..b6a31def0c5b8b4bbab3ce6781517a5866a08fba
base: 97eb6c26d0189f2eb0b7926d36e59a7d07b08a17
head: b6a31def0c5b8b4bbab3ce6781517a5866a08fba
rounds: [97eb6c26d0189f2eb0b7926d36e59a7d07b08a17, 2e82fcbda3c1abe4505a9a77b5c872321fab2b00]
paths: []
about: [PRJ-0001]             # the pages it is about: experiments, runs, a project
status: changes_requested # open | changes_requested | approved | merged | closed
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
- 2026-11-03 17:38 ank requested changes: Pull the yajna upstream and run the same steps again. I have added some new features to yajna

## Threads

### T1 (open) general
- 2026-11-03 17:55 agent:claude: Round 2, as requested (b6a31de): yajna 0.22.1 → 0.23.0 (2c665ad shell completion, 742f1fc run … --on <host>), skill copy regenerated (one new line). T0 319/319; kalam builds; ank@rogue, rogue's system and ank@ghost001 evaluate; yajna validate passes on all 18 pages. Not wired: completion in ank's zsh. It would be one line in the yajna home bundle (modules/users/ank/ank.nix): programs.zsh.initContent with source <(COMPLETE=zsh yajna). Say if you want it.
- 2026-11-03 17:58 ank: add the zsh completion to ank's zsh
