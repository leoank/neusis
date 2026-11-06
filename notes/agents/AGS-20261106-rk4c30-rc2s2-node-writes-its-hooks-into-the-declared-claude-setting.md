---
id: AGS-20261106-rk4c30
type: agent_session
schema_version: 1
title: rc2s2-node writes its hooks into the declared Claude settings, since a switch rewrites settings.json without them
model: "claude-opus-5-5"
harness: "claude-code"
started: 2026-11-06T22:23+00:00
finished: 2026-11-06T22:27+00:00
created_entities: []
edited_entities: []
outcome: done             # done | failed | aborted | pending
created: 2026-11-06
author: agent:claude
---

## Task
The owner found that a session spawned from the phone failed every permission prompt.
In rc2s2 the cause was rogue's `~/.claude/settings.json` without rc2s2's hooks; the
owner pointed out that a switch rewrites that file, and asked for the hooks in the
neusis config.

## What happened
- Confirmed: the agent harness installs `settings.json` on every switch from
  `tools.claude.settings` (ank.nix restates it with empty `PreToolUse` and
  `PostToolUse`), so a hand-merged hook block is lost at the next switch.
- `homeModules/rc2s2-node.nix` gains `claudeHooks`, on by default: it adds the block
  `rc2s2 node hooks` prints (nine events, an HTTP hook to `hookAddr`, 600 s) to
  `programs.claude-code.settings`, whose JSON type merges with the harness's own
  definition. The module's header no longer says it leaves settings.json alone.
- The 600 s timeout matches the hooks the rc2s2 node passes to the sessions it spawns
  (rc2s2 ADR-0037, f3b8c5c), so Claude Code sees one hook there, not two.
- Checks: T0 `nix run .#neusis-test` 328/328 with the new
  `hm-rc2s2-node.test-hooks-in-claude-settings`; rogue's evaluated settings carry all
  nine events, `PreToolUse` merged; `nix build .#darwinConfigurations.rogue.system`
  builds, and its `claude-code-settings.json` has the hooks. Not switched, not
  committed.
- Decided without asking: on by default inside the module (the daemon is of little
  use without its hooks), no ADR (a module default, recorded in its header).
