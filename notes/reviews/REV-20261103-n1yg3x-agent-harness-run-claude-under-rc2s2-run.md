---
id: REV-20261103-n1yg3x
type: review
schema_version: 1
title: "agent-harness: run claude under rc2s2 run"
project: PRJ-0001
target:
  kind: range               # branch | range | page | run | experiment | phase
  ref: HEAD..706a999b8a6001af705f67ce849d75d85b95516b
base: 66754dc99ea9b032cc8ae6e3b181aa850ac47072
head: 706a999b8a6001af705f67ce849d75d85b95516b
rounds: [66754dc99ea9b032cc8ae6e3b181aa850ac47072]
paths: []
about: [PRJ-0001]             # the pages it is about: experiments, runs, a project
status: approved          # open | changes_requested | approved | merged | closed
created: 2026-11-03
author: agent:claude
---

## Summary
`706a999` adds `neusis.agent-harness.tools.claude.rc2s2` (opt-in). When it's on, the `claude` that `programs.claude-code` installs is a small wrapper:
- at a terminal it runs `rc2s2 run --command <claude> -- "$@"`, a PTY the rc2s2 node daemon can interrupt and kill from the phone;
- without one (stdin or stdout not a tty) it execs claude directly.

On Linux `<claude>` is the jailed claude. home-manager wraps the package with its `--plugin-dir`, which passes through `--`. ank's agent-harness bundle sets it from `config.neusis.services.rc2s2-node.enable or false`, so it is on where the daemon runs: rogue. ghost001 has no agent harness.

Checks:
- T0 320/320 on both test sets. New: `hm-agent-harness.test-claude-under-rc2s2-run` (off by default; on, the wrapper has both branches); `machine-rogue.test-users-and-homes` asserts it's on for rogue.
- Tried on rogue (daemon running), with rogue's real `finalPackage`:
  - under a pty, `bash -x` shows `exec rc2s2 run --command …/claude -- --plugin-dir /x --version`;
  - from a pipe, `exec …/claude --version`;
  - both print `2.1.316 (Claude Code)`.

Not tried: a full interactive session interrupted from the phone, and Linux in practice (no Linux host runs the daemon).
- 2026-11-03 20:30 ank approved: I tried it on rogue, and it works. Approving this. If issues crop up later in linux, we'll work on it on a separate review.

## Threads
