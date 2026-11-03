---
id: AGS-20261103-hqkbgv
type: agent_session
schema_version: 1
title: "kalam-zero phase 5: the rolling GitHub release and docs/kalam/zero.md"
model: claude-opus-5-5
harness: claude-code
started: 2026-11-03T16:08+00:00
finished: 2026-11-03T16:16+00:00
created_entities: [REV-20261103-hv2prm]
edited_entities: []
outcome: done             # done | failed | aborted | pending
created: 2026-11-03
author: agent:claude
---

## Task
kalam-zero phase 5 (ADR-0016): publish `init.lua` on a rolling GitHub release, and write `docs/kalam/zero.md`.

## What happened
- `.github/workflows/kalam-zero-release.yml` runs on pushes to main that touch kalam, its tests or `flake.lock`, and by hand. It:
  - runs the six x86_64-linux headless checks (0.8 to 0.12);
  - builds `kalam-zero-init` and writes `init.lua.sha256`;
  - moves the `kalam-zero` tag and creates or edits the release (`--latest=false`, so CLI `v*` releases stay latest), replacing its two files.

  actionlint passes. The release step ran locally with `git` and `gh` stubbed to check the notes it writes.
- `docs/kalam/zero.md`: install over curl, wget or ssh with no internet on the target, the `-u` path for 0.8 and read-only homes, checksum, update and removal; features by Neovim version; the shortcut table; differences from kalam; troubleshooting (OSC 52 in tmux).
- Linked from `docs/kalam/base.md`, `docs/architecture.md` and the site's kalam tutorials. The site builds with no broken relative links.
- First release run (Actions 41672011730) passed every step; tag `kalam-zero` at `d55dc55`. The published file matches its checksum. Downloaded from the release URL, it passes 121 checks locally, run with `env -u VIMINIT`: this shell sits inside kalam's terminal, whose VIMINIT overrides init.lua.
- It differs from a darwin build only in the order of oil's two syntax files (locale collation), and GitHub treats it as `releases/latest` while it is the only release. Both are threads on [[REV-20261103-hv2prm]].
- Opened [[REV-20261103-hv2prm]] over `c7b40fa..d55dc55`, the whole build, with 9 threads from my own read-through.
