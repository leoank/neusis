---
name: yajna
description: Work in a yajna lab notebook (a repo with yajna.toml): record experiments, runs, log lines and agent sessions through the yajna CLI, following its conventions. Use whenever a task touches a notes/ vault, a PRJ/EXP/RUN page, or asks to record, reproduce or query lab work.
---

# yajna: the lab notebook

The repo you are in holds a notebook of plain markdown pages under `notes/` with typed
frontmatter. `yajna.toml` at the root says whether it is a `lab` (many projects plus shared
protocols, materials, equipment) or a `project` (one project's notebook inside its code
tree). The `yajna` binary creates and checks pages; never write a page by hand.

## Before anything else

1. `yajna --version` works from the repo's dev shell (`nix develop`). Run every command
   from the repo root, or pass `--root <path>`.
2. Say who you are: export `YAJNA_AUTHOR=agent:<name>` for the session (or pass
   `--author agent:<name>` to each command). Every page and log line you create must carry
   your handle, never the human's. `<name>` is your harness, lowercase: `agent:claude`.
3. Read, in this order: the project page (`notes/projects/PRJ-xxxx-*/README.md`, or
   `notes/README.md` in a project repo) for *Current belief*, *Open questions* and *What not
   to try again*; then `yajna tree PRJ-xxxx` for the experiments with outcomes; then the
   experiment you are working on and `yajna runs EXP-xxxx` for its runs.
4. Open a session page: `yajna new agent "<task>"` gives an `AGS` page, one per task the
   author hands you (a new request in the same conversation is a new page). Fill `model`
   and `harness` at once, keep `created_entities` and `edited_entities` current, write
   *Task* in a few lines and *What happened* as you go, including what you decided
   without asking. When you finish, set `outcome` and `finished` (the time of your
   closing log line, not a guess). `yajna validate` fails a day you logged without a
   session page running that day.

## Commands

```
yajna new experiment "<question>" --project PRJ-xxxx      # curated; fill Question, Hypothesis, Plan, Success criteria
yajna new run --experiment EXP-xxxx --kind compute --script notes/projects/PRJ-xxxx-*/runs/RUN-<id>/run.sh
yajna result --experiment EXP-xxxx run.log --script <path>   # metric runs: ===RESULT=== line -> RUN page + results.tsv
yajna log "<what you did and learned, with [[IDs]]>"       # your own file for the day
yajna new agent "<task>"                                   # the AGS page for this session
yajna show <ID> | timeline <ID> | tree PRJ-xxxx | runs EXP-xxxx --by <metric>
yajna todo "<text>" [--due fri] [-p 1]                     # a loose todo in notes/tasks.md
yajna tasks                                                # open checkboxes across the vault, numbered
yajna log|todo|tasks --in <notebook>[/<project>] …         # another notebook on the machine (yajna repos)
yajna review open HEAD..HEAD --title "<the work>"          # the review your changes go under (once per piece of work)
yajna review about REV-… EXP-… RUN-…                       # what the review's work serves
yajna review todo                                          # the review threads you owe on this branch
yajna review list --open | show REV-… [--diff]             # reviews of your branch and what they ask
yajna review show REV-… --round | --fixes                  # since the last update; each fix on its own
yajna review reply|address REV-… T<n> "<text>" [--commit <sha>]   # answer; address with the fixing commit
yajna review update REV-…                                  # after new commits: move the head, re-anchor threads
yajna validate                                             # run before you report anything as done
```

`yajna new run` does not know the path of the page it will create until it allocates the
ID, so create the run first, then write the script at the path printed on the page
(`script:` in its frontmatter) and fill the page.

Pass every argument: without a terminal a missing one is an error, not a prompt. The last
line `yajna new` prints is the new page's path (`f=$(yajna new ... | tail -1)`). In a
`project` repo `--project` is not needed. A new page is a template: fill each section and
replace its placeholder lines (`If H1 is true we expect ...`, an empty `1. `); keep the
one-line instructions under headings such as *Runs*.

## Conventions you must follow

- **IDs are allocated by the CLI**: date IDs for experiments, analyses, runs, artifacts and
  sessions (`EXP-20261021-0k3m9x`), counters for projects, protocols, materials, equipment
  and builds (`PRO-0012`). An ID from before `yajna migrate-ids` still works in commands;
  write the current one in pages. Never reuse,
  renumber or hand-edit an ID or `notes/counters.yaml`.
- **Link with `[[ID]]`**, `[[ID|label]]`, `[[PRO-0012@3]]` for a protocol version,
  `[[ns/ID]]` into another repo listed in `[repos]`. A link to an unknown ID fails
  validation. Cite papers as `@citekey` from `references/library.bib`.
- **Keep *Progress* current.** The project page's *Progress* checklist is the quick view
  of what is planned and done: tick an item when its work lands, add one when the plan
  grows, never delete a done item.
- **A code project's design lives with its code.** `yajna new project --code` creates
  `code/<slug>/docs/architecture.md` and `code/<slug>/docs/decisions/` (in a `project`
  repo, `docs/` at the root). Keep the architecture current when the design changes, and
  record each decision, with the alternatives considered, as a new `ADR-xxxx-*.md` there
  plus a row in its README; never rewrite an accepted one, supersede it.
- **List children with one line each.** On a project page `- [[EXP-20261021-0k3m9x]] what it asks
  and what came of it`; on an experiment page `- [[RUN-20261016-k7f3x1]] what was tried and
  what it showed`. A bare `- [[ID]]` fails validation; the line is what the site shows
  next to the ID. `yajna new` and `yajna result` add the line (a run's says "not yet
  described"); rewrite it when the outcome is known.
- **Log, do not narrate in pages.** `yajna log` appends `- HH:MM text` to
  `notes/log/<year>/<date>.<author>.md`. Lines are appended, never reordered or edited.
  Log when you start, when something surprises you, and when you finish, linking the pages
  the line is about and your `AGS` page.
- **One run per result the experiment will rest on**, not one per command. A `RUN`
  page has kind `compute` for anything executed, `bench` for bench sessions.
- **Curated pages are human-signed.** When you edit an `EXP`, `PRO` or `MAT` page, set
  `review: pending` in its frontmatter; only a human signs it off (`yajna approve`, or a
  review that covers it), never you. Rewrite *Current belief*;
  append everywhere else. The *Conclusion* of an experiment is written
  once, by a human: propose it in the log or the `AGS` page instead.
- **Your changes go under a review.** Keep one `REV` page for the piece of work you are
  doing and add to it rather than opening one per change. Look first: `yajna review list
  --open` and `yajna review todo`; continue the unfinished review of your work when there
  is one. Otherwise, before you change anything, open one: `yajna review open HEAD..HEAD
  --title "<the work>"` (on a worktree branch, `yajna review open <branch>`). After each
  commit, `yajna review update REV-…` takes the new commits in; what is not committed yet
  shows in `yajna serve --review` as not in the review. Record what the work serves with
  `yajna review about REV-… <EXP-… RUN-… PRJ-…>` (validate fails an agent's review that
  says nothing about it) and link the review from your `AGS` page and log. Before starting the next major piece of work, ask the human to
  finish the current review (approve it, or say it is done); open a new one only then.
- **Reviews are answered, not resolved, by agents.** When a `REV` page reviews your
  branch, answer each thread with `yajna review reply`, or fix it, commit, and run
  `yajna review address REV-… T<n> --commit <sha> "<what changed>"`, one commit per
  fix where you can: the human reads each named commit on its own (`show --fixes`). Run
  `yajna review todo` when you start and before you report a branch as done; it lists
  what is still owed. Only a human resolves, approves and merges.
- **Fix a past range on a branch from its head.** When a commit-range review asks for
  changes and other work has landed after its `head`, do not fix on top of that work:
  `git worktree add ../fix-REV-… -b fix/REV-… <head>`, commit the fixes there, address
  the threads with those commits, and tell the human to run `yajna review update REV-…
  --to fix/REV-…` (the next round is then the fixes alone) and to merge the branch.
- **Large files never go into git history.** Results that matter become `ART` pages;
  ask before adding anything over a few MB.
- **Never delete.** Mark `status: abandoned` or `aborted`; git history is the record.

## Working in a worktree

Other agents may be working in other worktrees of the same notebook at the same time.

- If the repo root has `.yajna/author`, it names you for this worktree; do not set
  `YAJNA_AUTHOR` over it. Start parallel work with `yajna worktree PRJ-xxxx <topic>`.
- Stay inside your branch's project. Do not create or edit protocols, materials,
  equipment or builds on a branch; ask for them on `main`.
- Create experiments and analyses on your branch freely: their date IDs never collide.
  Projects and shared entities are made on `main`. If you did allocate a counter ID on the
  branch, run `yajna validate --against main` before reporting the branch as ready and fix a
  collision with `yajna renumber <ID>`. Never edit an ID by hand.
- Merge `main` into your branch before allocating anything, and never use a bare
  `git stash`.

## Designing and planning

Design work is recorded as it is done, not reconstructed afterwards.

- **The author decides what is theirs to decide**: scope, trade-offs, what to depend on,
  what users will see. Ask with the options and a recommendation; one answer can change
  the next questions, so ask in rounds. Settle conventional details yourself and say so.
- **Every accepted decision becomes a decision record** with its alternatives. A
  feature too big for a section of the architecture gets its own design document, linked
  from `architecture.md`.
- **Plan an experiment for each assumption the design rests on that nobody has checked
  against the real thing**: an external API or export format, a filesystem, a size or a
  speed. Its predictions say what result changes the plan, and it runs before the step
  that depends on it. Check what an external system really returns before designing a
  round trip on it.
- **The plan goes on the project page**: a *Progress* item per buildable step, naming the
  experiment that de-risks it; new questions in *Open questions*; the experiments with
  their one-line descriptions.
- **When an approach is dropped**, add a line to *Lessons* (or *What not to try again*):
  what was tried, why it failed, with links. A safety check that trusts a record of an
  action instead of looking at its result is a typical entry.

## Docs for people

Meeting notes, proposals, reports and admin pages are `doc` pages:
`yajna new doc "<title>" --kind meeting|proposal|report|admin|logistics|note --dir <dir>`.
Ask the author where it should live if they have not said (a thesis folder is common);
they sync to Google Docs by default. A meeting doc is a series: add each new meeting as a
`## <date>` section at the top (agenda, notes, decisions, actions as checkboxes,
transcript), set `date` to it, and keep earlier meetings below.
A document that already exists (a proposal drafted beside the thesis, notes from
elsewhere) becomes a page with `yajna adopt <file> --type <type> --kind <kind>` rather
than being retyped; run it with `--dry-run` first and tell the author it renames the file.
A page can cite from its own `.bib` with `bibliography: <file>.bib` in its frontmatter.
A page with `sync: {provider: gdoc, mode: mirror}` gets edits made in its doc back:
`yajna sync pull` merges them into the page as an uncommitted change. Show the author the
`git diff` and leave conflict markers (`<<<<<<< this page` / `>>>>>>> the doc`) for them
to resolve unless they ask you to; never use `yajna sync --overwrite` unasked, it
discards the doc's edits. A mirror page publishes only once committed. A pull can be
thrown away (`git checkout -- <file>`) and pulled again; if the author keeps only some of
the doc's edits, `yajna sync` refuses to publish over the rest, and choosing
`--overwrite` then is theirs.

## Reproducible runs

Every `compute` run you record must be re-creatable by someone who has only the repo:

1. Record `commit` (the repo commit the run executed at; `yajna result` fills it) and
   `script` in the run's frontmatter. `yajna new run --script <path>` writes a stub at
   that path if it does not exist, under `runs/RUN-<id>/run.sh` beside the page.
2. The script runs from the repo root inside the project's dev shell
   (`nix develop ./code/<slug> -c <script>`), pins or derives every input it needs
   (data paths, seeds, model versions, environment variables), and produces the same
   outputs: files under the run's directory and, for metric runs, one
   `===RESULT=== {...}` line on stdout.
3. Record in `Notes` what the script does not control (hardware, network, time) and what
   differed between the run and the plan. `yajna validate` fails when `script` points at
   a file that does not exist.

Hand-recorded runs that were not scripted (an interactive session, a one-off probe) say so
under `Notes` and still leave a script that gets as close as possible.

## Starting a project

A new project starts with an interview, not a guess: `/yajna:project <brief>` (and
`/yajna:code-project`, `/yajna:bio-project`, `/yajna:ml-project`,
`/yajna:hardware-project` for their domains) reads the notebook, asks the author the
questions that pin the project down, and only then creates the pages.

## Finishing

Run `yajna validate` (and `nix flake check` if the repo's AGENTS.md asks for it), update
the `AGS` page, log a closing line, and follow the repo's AGENTS.md for commits: by
default, commit only when asked and stage files by path.

- Nix sees only files git knows: before `nix flake check` or `nix build`, mark new pages
  and files with `git add -N <paths>`, or the notebook's check never reads them.
- Other people and agents may have uncommitted changes in the same tree. Commit only the
  files your task touched (`git commit --only <paths>` keeps anything already staged out
  of it), and say which changes you left alone.
- Report what you checked and what you could not, and name the decisions the author
  should look at.
