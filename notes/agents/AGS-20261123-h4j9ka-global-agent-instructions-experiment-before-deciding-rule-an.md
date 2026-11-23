---
id: AGS-20261123-h4j9ka
type: agent_session
schema_version: 1
title: "Global agent instructions: experiment-before-deciding rule, and the Lab Notebook section brought up to current yajna"
model: claude-opus-5-5
harness: claude-code
started: 2026-11-23T15:36+00:00
finished: 2026-11-23T15:36+00:00
created_entities: []
edited_entities: []
outcome: done             # done | failed | aborted | pending
created: 2026-11-23
author: agent:claude
---

## Task
ank: add the experiment-before-deciding rule to the global agent instructions
(`modules/homeModules/agent-harness/AGENTS.md`, deployed as `~/.claude/CLAUDE.md` and the
other harnesses' AGENTS.md), and bring its Lab Notebook section in line with current yajna.
This page was opened after the edit, not before it.

## What happened
- Checked current yajna rather than memory: `yajna --help` (0.41.1 on PATH; the plugin
  cache has 0.43.2), the yajna repo's skill at d35a617, `yajna repos`.
- Section 7 rewritten: pages under `notes/` (not `lab/`), lab vs project notebooks,
  `yajna repos`, the repo's own skill first (and say when it is stale), agent identity and
  `.yajna/author`, a session page per task before the work, the experiment-first rule
  (pages before probing, run, record, then decide), REV reviews and human sign-off,
  Progress in PHS phases where a project has them, `yajna data` for large files,
  `log|todo --in`, date IDs in the example. Kept: ask before creating a notebook; answer
  research questions from the notebook.
- Found, not fixed: neusis's `.claude/skills/yajna/SKILL.md` is older than the yajna repo's
  (no phases, `yajna data`, codified protocols, `@ work` threads); `yajna repos` shows the
  pinned saarthi path `~/workspace/hub/leoank/saarthi` as missing.
- T0 353/353. Not committed: ank had not asked for this one.
