# kalam (base) — the git workflow

How to drive day-to-day git, history exploration, code review, and
GitHub PR work without leaving nvim. Worked examples first, key
charts at the end.

The base flavor wires four plugins, each owning a clean slice of
the surface:

| Plugin       | Owns                                                                                  | Lives at     |
| ------------ | ------------------------------------------------------------------------------------- | ------------ |
| `gitsigns`   | The gutter signs + per-hunk operations (stage/reset/preview a single change).         | every buffer |
| `neogit`     | Magit-style status / commit / merge / push / rebase popups.                           | `<leader>gg` |
| `diffview`   | Side-by-side diffs and file-history walking.                                          | `<leader>gd` |
| `octo`       | GitHub issues, pull requests, reviews, comments — shells out to `gh`.                 | `<leader>go` |

Mental model in one line: **gitsigns** = lines, **neogit** = repo,
**diffview** = diffs, **octo** = github.

---

## 0. One-time setup

`gh` is bundled with the package, but it's not authenticated until
you tell it who you are. Run once per machine:

```bash
gh auth login          # follow the device-code prompt
gh auth status         # verify
```

Without this, `<leader>go*` will return "gh: authentication required".
Everything else (gitsigns, neogit, diffview) works against any
local git repo and needs no setup.

---

## 1. The daily commit

The most common loop: edit code, stage a subset of changes, write
a message, push.

**Worked example.** You changed three files but only want the
first two in this commit:

1. `<leader>gg` — opens the neogit status buffer in a new tab.

   ```
   Head:    main What we shipped yesterday
   Push:    origin/main

   Untracked (0)
   Unstaged changes (3)
     modified   src/auth/token.rs
     modified   src/auth/session.rs
     modified   README.md
   Staged changes (0)
   ```

2. Cursor on `src/auth/token.rs`, press `s` — stages it. Magit
   muscle memory: `s` stage, `u` unstage, `x` discard, `Tab`
   expand the diff inline, `<CR>` jump to the file.

3. Move to `session.rs`, press `s` again.

4. Press `c` — opens the commit popup. The popup is a list of
   flags you can toggle (`-a` amend, `-s` sign-off, `-S` GPG
   sign…). Press `c` *inside* the popup to start composing.

5. A new tab opens with the commit message buffer:

   ```
   feat(auth): rotate refresh tokens on session resume

   # On branch main
   # Changes to be committed:
   #   modified:   src/auth/token.rs
   #   modified:   src/auth/session.rs
   ```

6. Write the message, `:wq` — neogit confirms `[main abcdef1]
   feat(auth): …` in a notification.

7. Back in the status buffer, press `P` — push popup. Press
   `p` (`push to pushRemote`) — done.

Same pattern for amend (`c a c`), fixup (`c f`), squash. The
popup tree is the actual documentation: press `?` from any
neogit buffer for the keymap reference.

---

## 2. Selective hunk staging

Sometimes a single file holds two unrelated changes you want in
separate commits. Neogit can do this (move cursor onto a hunk in
the unstaged section, `s` stages just that hunk) but the
gutter-level flow is faster when you're already editing.

**Worked example.** You're in `token.rs`. The gutter shows two
change blocks: lines 10–14 (the bugfix you want now) and lines
80–95 (a refactor that should be its own commit).

1. Cursor on line 10, `<leader>ghp` — preview the hunk. Confirm
   it's the bit you want.
2. `<leader>ghs` — stage that hunk.
3. `]h` — jump to the next hunk (lines 80–95).
4. `<leader>ghp` — preview. Nope, leave it.
5. `<leader>gc` — commit. Compose, save, done. The other hunk
   stays unstaged.

For *partial* hunk staging — staging only some lines of a hunk —
select the lines in visual mode and `<leader>ghs`. gitsigns
splits the hunk for you.

---

## 3. Reading history (whole repo)

You want to understand what shipped this week.

- `<leader>gl` — neogit log popup. Press `l` (current branch) or
  `o` (other ref). A scrollable log opens, one commit per line.
- `<CR>` on a commit — opens the diff in a side pane.
- `d` on a commit (from inside the log) — opens that commit's
  diff in diffview, so you get a real two-pane view with
  per-file navigation.

For something more graph-oriented, `<leader>gdh` (DiffviewFileHistory
with no path argument) walks the whole repo's history with a file
panel that lets you jump between changed files in each commit.

---

## 4. Reading history (one file)

This is the canonical "when did this function break?" flow.

**Worked example.** `parseToken` works on `main` but fails on
your branch. You want to see every commit that touched
`src/auth/token.rs`.

1. Open `src/auth/token.rs`.
2. `<leader>gdf` — DiffviewFileHistory of `%` (the current file).
3. A two-pane layout opens. Right: the file at the selected
   commit. Left: the file at the parent. Top-right: the list of
   commits, newest first.
4. `j`/`k` to walk commits. The diff updates as you move.
5. `g?` (from inside diffview) — the help panel, lists every
   binding for this view.
6. `<C-w>w` to focus the diff and read normally — search with
   `/`, jump to definition, whatever.
7. `:DiffviewClose` or `<leader>gdd` — back to where you were.

Variants:
- `:DiffviewFileHistory path/to/other.rs` — explicit path
- `:DiffviewFileHistory % --range=HEAD~10..HEAD` — last 10 commits
- `:DiffviewFileHistory -- src/auth/` — every file in a subtree

---

## 5. Toggling a diff on the current file

Sometimes you just want to see "what did I change in this file
since HEAD?" without opening status or scrolling the gutter.

- `<leader>gdd` — toggle. First press opens the working-tree-vs-
  HEAD diff for the whole worktree. Second press closes it and
  returns you to the file/cursor you were on.
- `<leader>gdo` — explicit open (same thing without the close).
- `<leader>gdc` — explicit close.

Once inside, the file panel on the left lists every changed
file; `<Tab>`/`<S-Tab>` cycle. `g?` shows the help panel.

---

## 6. Merging a branch

```
<leader>gg                 # status
m                          # merge popup
m                          # "merge a branch"
<select branch from list>
```

If there's no conflict, neogit reports the merge commit and
you're done. If there's a conflict:

1. The status buffer now shows an "Unmerged" section listing the
   conflicted files.
2. Cursor on a conflicted file, `d` — opens diffview in 3-way
   mode (`OURS`, `BASE`, `THEIRS`, `RESULT`).
3. Inside diffview's 3-way layout:
   - `<leader>co` — take OURS for this hunk
   - `<leader>ct` — take THEIRS
   - `<leader>cb` — take BASE
   - `<leader>ca` — take all (rare; usually wrong)
   - `]x` / `[x` — next/prev conflict hunk
4. Save the RESULT pane.
5. Back in the status buffer, `s` stages the resolved file.
6. When all conflicts are resolved, `c c` to compose the merge
   commit. Neogit pre-fills the standard merge-commit message.

Same flow for rebase conflicts — `R` instead of `m` at step 1,
`r` to continue / `s` to skip / `a` to abort from the rebase
popup.

---

## 7. Reviewing a pull request

The PR review workflow is the one octo really shines at.

**Worked example.** Teammate opens PR #142, asks for review.

1. `<leader>gop` — opens a snacks picker listing open PRs. Type
   `142` to filter, `<CR>` to open.
2. The PR opens as a buffer: title, body, labels, status checks,
   timeline of comments. Read it.
3. `<leader>goh` — `Octo pr checkout`. Octo runs `gh pr checkout
   142` in the background; your worktree is now on the PR
   branch.
4. `<leader>gor` — `Octo review start`. Octo opens the diff for
   the PR using diffview's UI.
5. Walk files: `<Tab>` / `<S-Tab>` to cycle, `j`/`k` inside the
   diff to scroll.
6. To leave a line comment: visual-select the lines you want to
   comment on (in the *new* side of the diff), then `<leader>goc`.
   A comment buffer opens. Write the comment, `:wq`.
7. To suggest a change instead of just commenting: write the
   comment in the suggestion-block format (octo's comment buffer
   has `[Add Suggestion]` virtual text at the top — see `:Octo`
   tab completion for the command).
8. When done reviewing all files, `<leader>gof` — `Octo review
   submit`. A small picker asks you to choose **comment**,
   **approve**, or **request changes**. Pick one. Optionally
   write a summary. Submitted.
9. `<leader>goR` — `Octo review resume` if you started a review
   earlier, closed nvim, and came back to it. Octo remembers
   pending review state on GitHub's side.

To approve quickly without a full review: open the PR buffer
(`<leader>gop` → `<CR>`), then `:Octo pr approve`.

---

## 8. Opening a pull request

You've committed and pushed your branch.

1. `<leader>goP` — `Octo pr create`. A small popup asks for the
   base branch (defaults to the repo's default branch) and the
   head branch (defaults to your current branch).
2. A draft PR buffer opens with title prefilled from the first
   commit's subject and body from the commit body.
3. Edit title/body. `:Octo pr ready` toggles draft-mode if you
   want it as a real PR (or pass `--draft` to keep it as draft).
4. `:wq` — octo creates the PR via `gh`, then re-opens it as a
   normal PR buffer.
5. From here: `:Octo pr assign you`, `:Octo label add wip`,
   `<leader>goc` to add comments.

---

## 9. Issue triage

Same shape as PRs, simpler.

- `<leader>goi` — list issues (picker).
- `<leader>goI` — create one. A buffer opens, write title + body,
  `:wq`.
- `<leader>gos` — search across issues with a query string.
- Once an issue is open as a buffer:
  - `<leader>goc` — add a comment (works in visual too, but
    rarely useful for issues).
  - `<leader>go+` / `<leader>go-` — react with 👍 / 👎 on the
    issue or the comment under the cursor.
  - `:Octo issue close` / `:Octo issue reopen` — state changes.
  - `:Octo label add bug priority/high`
  - `:Octo assignee add octocat`

The full `:Octo <noun> <verb>` tree is tab-completable. For the
list of nouns and verbs, `:help octo` once inside nvim.

---

## 10. The bindings cheat sheet

```
<leader>g                  GIT
  g       neogit status (the front door)
  c       commit popup
  m       merge popup
  p / P   pull / push popup
  R       rebase popup
  B       branch popup
  z       stash popup
  l       log popup
  b       blame current line (snacks popup)
  W       open current line on the remote (github / forge)

<leader>gh                 HUNKS (gitsigns)
  s / r   stage / reset hunk        (v-mode for partial)
  S / R   stage / reset buffer
  u       undo stage hunk
  p       preview hunk in popup
  b       blame line (full info)
  d       diff this file vs HEAD
  (]h / [h navigate hunks)

<leader>gd                 DIFFVIEW
  d       toggle (open if closed, close if open)
  o / c   explicit open / close
  h       repo file history (all files, all commits)
  f       this file's history (the canonical single-file walk)
  r       refresh
  F       toggle file panel

<leader>go                 GITHUB (octo)
  i / I   issues: list / create
  s       issues: search
  p / P   PRs: list / create
  S       PRs: search
  r / R   PR review: start / resume
  f       PR review: submit (final step of a review)
  h / m   PR: checkout / merge
  c       comment add        (v-mode for line-range review comments)
  C       comment delete
  + / -   react thumbs up / down
```

In-buffer bindings (inside neogit / diffview / octo buffers) are
discoverable via `?` (neogit), `g?` (diffview), and tab-completion
on `:Octo` (octo). They're not shown here because they're
plugin-native, not configured by kalam.

---

## 11. Where the configuration lives

- [`plugins/git.nix`](../../new_modules/packages/kalam/_flavors/base/config/plugins/git.nix) —
  gitsigns + neogit + diffview + octo setup and all leader-bindings.
- [`plugins/whichkey.nix`](../../new_modules/packages/kalam/_flavors/base/config/plugins/whichkey.nix) —
  declares the `<leader>g{d,h,o}` subgroup labels so the popup is
  navigable.
- [`plugins/snacks.nix`](../../new_modules/packages/kalam/_flavors/base/config/plugins/snacks.nix) —
  owns `<leader>gb` (blame popup) and `<leader>gW` (gitbrowse).

`gh` is added via `extraPackages` in `git.nix`, so the binary is
available inside the kalam neovim wrap without requiring a
separate install.

---

## 12. Troubleshooting

**`gh: authentication required`** — run `gh auth login` once.
Octo only checks at first use, so the error shows when you try
`<leader>gop` for the first time.

**`E5108: octo` errors about missing fields** — usually means
`gh` is on an old version. Octo and `gh` move together. Bump the
nixpkgs input.

**Diffview "no changes" but you have changes** — diffview defaults
to `HEAD` as the right side. If you're on a detached HEAD or a
shallow clone, pass an explicit range: `:DiffviewOpen origin/main...HEAD`.

**Neogit complains about a missing diffview** — `integrations.diffview
= true` requires diffview to also be enabled. Both are turned on
in this config, but if you fork the flavor, keep them paired.

**`<leader>gdf` opens but shows nothing** — file has no history
(or has only one commit). `:DiffviewFileHistory %` will print
"no commits found for path".
