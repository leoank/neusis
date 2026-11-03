---
id: REV-20261103-k6bx64
type: review
schema_version: 1
title: "yajna 0.19 → 0.22: CLI, nvim plugin and the repo's skill copy"
project: PRJ-0001
target:
  kind: range               # branch | range | page | run | experiment | phase
  ref: HEAD..7b77d459faa2f062b0237b4968b64e8302ab4557
base: 97eb6c26d0189f2eb0b7926d36e59a7d07b08a17
head: 7b77d459faa2f062b0237b4968b64e8302ab4557
rounds: [97eb6c26d0189f2eb0b7926d36e59a7d07b08a17, 2e82fcbda3c1abe4505a9a77b5c872321fab2b00, b6a31def0c5b8b4bbab3ce6781517a5866a08fba, 511310d4d93ead8a36483b0758c10b14d8166463]
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

### T1 (addressed) general
- 2026-11-03 17:55 agent:claude: Round 2, as requested (b6a31de): yajna 0.22.1 → 0.23.0 (2c665ad shell completion, 742f1fc run … --on <host>), skill copy regenerated (one new line). T0 319/319; kalam builds; ank@rogue, rogue's system and ank@ghost001 evaluate; yajna validate passes on all 18 pages. Not wired: completion in ank's zsh. It would be one line in the yajna home bundle (modules/users/ank/ank.nix): programs.zsh.initContent with source <(COMPLETE=zsh yajna). Say if you want it.
- 2026-11-03 17:58 ank: add the zsh completion to ank's zsh
- 2026-11-03 18:17 agent:claude addressed in 511310d: In the yajna hmBundle (modules/users/ank/ank.nix): COMPLETE=zsh yajna is generated at build time (the hook calls the yajna on PATH, so it stays right across updates and costs nothing at shell start) and sourced from programs.zsh.initContent when zsh is enabled; in rogue's .zshrc it comes after oh-my-zsh.sh, which runs compinit. Tried in zsh: 'yajna show EXP<Tab>' offers EXP-20261103-g9kpxs with its status and title. rogue.test.nix checks it's sourced; T0 319/319. Takes effect after your home-manager / darwin switch.
- 2026-11-03 18:22 ank: Pull the yajna upstream and run the same steps again. I have added some more fixes to yajna

### T2 (open) general
- 2026-11-03 18:31 agent:claude: Round 3, as requested (7b77d45): yajna 0.23.0 → 0.24.0, upstream 742f1fc → 6a3cc92 (8661c4e run record --host and --env NAME=VALUE; 81e3e31 --on clones the origin to the host when nothing is there). The skill copy gains the run record --host line. T0 319/319; kalam builds; rogue's system and ank@ghost001 evaluate; ank@rogue builds, with its zsh completion regenerated from 0.24.0; yajna validate passes on all pages.
