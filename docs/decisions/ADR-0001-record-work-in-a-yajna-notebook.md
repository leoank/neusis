# ADR-0001: Record neusis work in a yajna project notebook, with decisions as ADRs, and freeze porting.md

Status: accepted
Date: 2026-11-03

## Context
Since 2026-05-31 every change, its rationale and its gotchas went into `docs/porting.md`,
one dated entry per piece of work. By November it was 2,600 lines that mixed three
things: decisions and the alternatives behind them, a running activity log, and
reference material (layout, schema cheat sheet, gotchas). Finding why something is the
way it is meant reading it end to end, and parallel work in several worktrees (with
several agents) would have every branch appending to the same file.

Alternatives considered:
- Keep `porting.md` as the only record. Simple, but the problems above grow with it.
- Keep `porting.md` as the narrative log and add ADRs only for large decisions. Two
  places for the same kind of entry, with no rule for which one a change belongs in.
- Add a yajna notebook but no ADRs, leaving decisions in `porting.md`. Keeps the
  biggest part of the problem.

## Decision
neusis is a project-shaped yajna notebook (`yajna.toml`, namespace `neusis`; the project
page is `notes/README.md`, PRJ-0001). From 2026-11-03:
- each design decision is an ADR in `docs/decisions/`, and `docs/architecture.md` says
  how the pieces fit;
- day-to-day work goes to `yajna log`, agents also record a session page
  (`yajna new agent`), and questions that need evidence become experiments and runs;
- `docs/porting.md` is frozen: no new entries, a note at the top pointing here.

## Consequences
- Rationale is findable by decision rather than by date, and parallel branches write to
  their own log files and ADRs instead of one shared file.
- The yajna CLI is needed to create pages; it is in the dev shell and in ank's home.
- The history before 2026-11-03 stays in `porting.md`, so for older decisions both
  places have to be read.
- `docs/` is also imported by the documentation site; the `[[ID]]` links in
  `architecture.md` show there as plain text.
