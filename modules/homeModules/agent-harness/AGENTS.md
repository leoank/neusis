Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

## 5. Nix Everywhere

**Every project is a Nix project. The machine may be too.**

I use Nix by default in all my projects. Assume a `flake.nix` at the repo
root (often with an `.envrc` running `use flake` for direnv) is the source
of truth for the toolchain and its dependencies.

Working inside a project:
- Run tools through the flake: `nix develop -c <cmd>`, or rely on direnv
  having loaded the dev shell. Don't assume a tool is on PATH outside it.
- A missing tool or library is added to the flake (`devShells`, `packages`,
  `buildInputs`), not installed ad hoc with `pip install`, `npm i -g`,
  `cargo install`, `brew install`, or `apt-get`. Language package managers
  (uv, pixi, cargo, npm) are fine *inside* the dev shell when the project
  already uses them.
- `flake.lock` changes only via `nix flake update <input>` / `nix flake lock`,
  and travel in the commit that changed the inputs. Don't hand-edit it.
- If `flake.nix` is generated (e.g. by `flake-file`, look for a header
  comment or a `write-flake` app), edit the source and regenerate.
- Verification goes through Nix too: `nix build`, `nix flake check`,
  `nix develop -c <test command>`. Prefer these over host-level commands.
- No `flake.nix`? Say so and ask before adding one — don't assume the
  project is an exception, but don't nixify it silently either.

Working on a neusis-managed machine:

My machines are configured by **neusis** (a flake-based NixOS / nix-darwin /
home-manager fleet config, github:leoank/neusis). Tell-tales: the file you
are reading is a symlink into `/nix/store/...-home-manager-files/`;
`darwin-rebuild` or `nixos-rebuild` is on PATH; `/run/current-system` exists;
`/etc/nix/machines` lists remote builders. When you see these:
- Dotfiles, shell config, editor config, installed CLIs and this very
  guideline file are **declared in the neusis repo and read-only on disk**.
  Never edit them in place (the store is immutable and the change would
  be lost on the next switch); never `rm` a symlink to replace it. Make
  the change in the neusis checkout (usually a folder inside `~/workspace/`)
  and rebuild. Read that repo's `AGENTS.md` before touching it.
- Installing software for me means adding it to my home bundle or the
  machine config in neusis, not `brew install` / `pip install --user`.
  System-level `brew` is managed through nix-homebrew in the same repo.
- Rebuilds are mine to run unless asked: `darwin-rebuild switch --flake .#<host>`,
  `nixos-rebuild switch --flake .#<host>`, or `home-manager switch --flake
  .#<user>@<host>`. Prefer a build-only check (`nix build .#…`,
  `nix flake check --no-build`) and leave the switch to me.
- Distributed builds are configured: a Linux build may be offloaded to a
  remote builder or a local linux-builder VM. Don't pass `--builders ''`
  to "simplify" things; it breaks configurations that need those builders.
- Secrets are agenix-rekey `.age` files. Never try to decrypt, print, or
  commit plaintext; edit via `agenix edit` only when asked.
- A dev shell from a project flake is still the right place to run that
  project's tools; the host profile is deliberately minimal.

## 6. Git Commits

**Commit only when asked. One concern per commit. The message carries the why.**

- Never commit, amend, rebase, or push unless I ask. "Commit this" means
  the change we just made, not everything in the working tree: stage the
  files that belong to it by path, never `git add -A` / `git add .`.
  Leave my other uncommitted work alone and tell me it is still there.
- Conventional-commit subjects: `type(scope): what and, when it is not
  obvious, why`. Types: `feat`, `fix`, `docs`, `test`, `ci`, `chore`,
  `refactor`, `perf`, `build`. The scope is the module, feature, package,
  user or host touched (`fix(kanata):`, `feat(ank):`, `docs(porting):`);
  drop it only for cross-cutting changes (`ci:`, `docs:`).
- Subjects are lowercase after the prefix, imperative or a noun phrase,
  and may run long when the rationale belongs in the first line
  (`fix(kanata): Restart=on-failure on the NixOS units — at boot kanata
  can start before udev applies the uinput group`). A short, vague
  subject is worse than a long, precise one.
- A body is optional. When present it is one or two short prose
  paragraphs wrapped at ~72 columns explaining motivation and
  non-obvious consequences, not a bullet list restating the diff.
- **No trailers.** No `Co-Authored-By`, no "Generated with …", no
  emoji, no tool attribution. The commit is mine.
- One concern per commit. Split unrelated changes even if they are
  small. Within a concern, everything travels together: the code, its
  test, its docs, and any generated or lock files the change produced
  (a `flake.nix` regenerated by `write-flake`, a `flake.lock` bump from
  `nix flake update <input>`). Never commit a lock change by itself
  without the input change that caused it, or vice versa.
- Verify before committing: the project's test or eval step
  (`nix flake check --no-build`, the unit suite, `go test ./...`) has to
  pass on exactly what is staged. Say which check you ran in your reply,
  not in the message.
- Work on the branch I am on. Don't create branches, worktrees or stashes
  to "protect" main unless I ask; I commit to `main` directly in my own
  repos. Never use a bare `git stash`; other sessions share the stack.
- Prefer `git pull --rebase=merges` (or plain `git pull`) when the branch
  carries a merge commit; plain `--rebase` flattens it.

## 7. Lab Notebook (yajna)

**Research work is recorded in a yajna notebook. Ask before starting a project without one.**

`yajna` (github:leoank/yajna) is my markdown-first lab notebook: a repo
with `yajna.toml` holds pages for projects, experiments, runs, protocols,
materials and a daily log under `lab/`, created and checked by the `yajna`
CLI. My notebook is the private `manthan` repo; a project may also carry
its own single-project notebook inside its code tree. The Claude plugin
`yajna` (installed on my machines) brings the `yajna` skill and the
`/yajna:project`, `/yajna:code-project`, `/yajna:bio-project`,
`/yajna:ml-project` and `/yajna:hardware-project` commands.

- When the directory has a `yajna.toml`, load the `yajna` skill and follow
  it: identify as `agent:<name>`, create pages only through the CLI, log
  what you did, record a session page, and keep runs reproducible.
- When I ask you to start something new (a project, an experiment, a
  spike, a piece of software or hardware) and no `yajna.toml` is in
  sight, ask me first whether it should live in the notebook: as a new
  project in `manthan` (`/yajna:project` and its variants interview me
  before creating anything), as a project-shaped notebook inside the new
  repo (`yajna init project`), or not at all. Do not decide this
  yourself, and do not scaffold a notebook unasked.
- Research-shaped questions ("what did we find about X", "which runs of
  EXP-0007 did best") are answered from the notebook (`yajna timeline`,
  `yajna tree`, `yajna runs`), not from memory.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.
