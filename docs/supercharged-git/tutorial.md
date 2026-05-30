# supercharged-git — tutorial

A walkthrough of the `neusis.supercharged-git` umbrella and the eleven
tool sub-modules that ship under it. Each section shows the
home-manager snippet to enable a piece, then a couple of concrete
workflows it unlocks.

This assumes you've already imported the umbrella into one of your
home-manager bundles:

```nix
imports = [ self.homeModules.supercharged-git ];
```

Importing the umbrella declares every `neusis.supercharged-git.tools.*`
option but enables none of them — you opt in piecemeal.

---

## 0. Minimum setup

The umbrella's own knobs (no tool needed) — drop this into any
home-manager bundle and you've got SSH-signed commits + LFS:

```nix
neusis.supercharged-git = {
  enable = true;
  userName = "Ankur Kumar";
  userEmail = "ank@example.com";
  # Optional: makes `git verify-commit` work locally.
  allowedSignersPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI…";
  # signingKey defaults to ~/.ssh/id_ed25519.pub
};
```

What you get out of the box:

- Every commit is SSH-signed (`commit.gpgsign = true`,
  `gpg.format = ssh`).
- `git-lfs` is installed and registered.
- `~/.ssh/allowed_signers` is written if you supply
  `allowedSignersPubkey`.
- `gclb` is on PATH (`git clone --bare` + worktree bootstrap in one
  command — see §13).

```sh
# Verify your most recent signed commit.
git log -1 --show-signature
# good "ssh" signature from "ssh-ed25519 …"
```

---

## 1. `gh` — GitHub CLI

```nix
neusis.supercharged-git.tools.gh.enable = true;
```

This enables `programs.gh` *and* pre-installs `gh-dash` and
`gh-copilot` as extensions. First-run auth:

```sh
gh auth login                # SSH key, browser flow
gh auth status               # confirm token + scopes
```

Daily workflows:

```sh
# Create a PR from the current branch, open in browser.
gh pr create --fill --web

# Watch the in-progress CI for the current PR.
gh pr checks --watch

# Triage assigned issues in a TUI.
gh dash

# Ask copilot to explain or generate a command.
gh copilot explain "find . -mtime -7 -name '*.nix'"
gh copilot suggest "compress logs older than 30 days"

# Cherry-pick a PR locally without leaving the shell.
gh pr checkout 1234
```

Override the extensions list if you want something else:

```nix
neusis.supercharged-git.tools.gh = {
  enable = true;
  extensions = with pkgs; [ gh-dash ];   # drop copilot
};
```

---

## 2. `lazygit` — TUI git client

```nix
neusis.supercharged-git.tools.lazygit.enable = true;
```

The default settings wire `delta` in as the diff pager (`delta` tool
must also be enabled for the pager to be on PATH), so hunks render
side-by-side inside lazygit too.

```sh
lazygit            # in any git repo
```

Keys you'll use constantly:

| Key | What it does |
|---|---|
| `space` | Stage / unstage the file under the cursor |
| `c` | Commit the staged changes |
| `P` | Push current branch |
| `p` | Pull |
| `b` | Branch panel — `space` to checkout, `n` to create |
| `enter` on a commit | Diff browser (Tab/N to navigate hunks) |
| `?` | Context-sensitive help (lifesaver) |

Common workflow: split a messy working tree into multiple commits
without leaving the TUI. Stage hunk-by-hunk with `a` on a file, mark
specific lines with `space`, commit, repeat.

Override settings if you want a different pager / keymap:

```nix
neusis.supercharged-git.tools.lazygit.settings = {
  git.paging.pager = "less --tabs=4 -RFX";
  gui.theme.activeBorderColor = [ "green" "bold" ];
};
```

---

## 3. `delta` — diff pager

```nix
neusis.supercharged-git.tools.delta.enable = true;
```

Defaults (this module ships them, no extra config needed):

- `features = "decorations navigate"`
- `navigate = true` — Tab/N jumps between hunks inside the pager
- `line-numbers = true`
- `side-by-side = true`
- `dark = true`

What changes:

```sh
git diff           # split view, syntax-highlighted, line numbers
git log -p         # same treatment in log output
git show HEAD      # ditto
```

In lazygit and `gh pr diff`, delta is picked up via the `pager`
setting — you get consistent rendering everywhere.

To go back to inline (single-column) diffs on a narrow terminal,
override `side-by-side`:

```nix
neusis.supercharged-git.tools.delta.options = {
  features = "decorations navigate";
  navigate = true;
  line-numbers = true;
  side-by-side = false;
  dark = true;
};
```

---

## 4. `pre-commit` — hooks framework

```nix
neusis.supercharged-git.tools.pre-commit.enable = true;
```

By default this also sets git's `init.templateDir` so every new
`git init`/`git clone` gets the `pre-commit` hook scaffold. Disable
with `autoInstall = false` if you want per-repo opt-in.

Per-repo setup:

```sh
# In a fresh repo, add a .pre-commit-config.yaml, then:
pre-commit install
pre-commit install --hook-type commit-msg     # for commitizen lint, etc.
```

Example `.pre-commit-config.yaml` for a Nix repo (paste into the
project root):

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v5.0.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: detect-private-key
  - repo: https://github.com/numtide/treefmt
    rev: v2.4.5
    hooks:
      - id: treefmt
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.21.2
    hooks:
      - id: gitleaks
```

Then `git commit` runs each hook; failures abort the commit. Run
manually any time with:

```sh
pre-commit run --all-files
```

---

## 5. `commitizen` — conventional-commit prompts

```nix
neusis.supercharged-git.tools.commitizen.enable = true;
```

Adds the `cz` binary and a `git cz` alias.

```sh
git add -p
git cz             # interactive prompt: type, scope, subject, body, footer
# → commits with a message like
#   feat(parser): handle escaped pipes inside backticks
```

Pair with a `commit-msg` pre-commit hook to enforce conventional
commits on contributors:

```yaml
# in .pre-commit-config.yaml
  - repo: https://github.com/commitizen-tools/commitizen
    rev: v3.31.0
    hooks:
      - id: commitizen
        stages: [commit-msg]
```

---

## 6. `gh-dash` — standalone PR/issue dashboard

```nix
neusis.supercharged-git.tools.gh-dash.enable = true;
```

Only needed if you want `gh-dash` on PATH without the rest of `gh` —
otherwise the `gh` tool module already installs it as an extension
(`gh dash`).

```sh
gh-dash            # full-screen PR + issue dashboard for repos you watch
```

Config lives at `~/.config/gh-dash/config.yml` — see
<https://github.com/dlvhdr/gh-dash#configuration> for the schema.

---

## 7. `jujutsu` (jj) — modern VCS, git-compatible

```nix
neusis.supercharged-git.tools.jujutsu.enable = true;
```

Seeds `user.name`/`user.email` from the umbrella's `userName`/`userEmail`,
so git and jj agree on identity.

Use it alongside git in any existing repo (colocated mode):

```sh
cd ~/code/some-git-repo
jj git init --colocate          # writes .jj/ next to .git/
jj log -r ::@                   # show ancestry of current change
jj new -m "WIP: refactor auth"  # create a new change on top of HEAD
jj diff                         # working-copy diff
jj squash                       # fold WIP into parent
jj git push --branch main       # push back through the git backend
```

Extra settings via `extraSettings` (merged into `programs.jujutsu.settings`):

```nix
neusis.supercharged-git.tools.jujutsu.extraSettings = {
  signing = {
    backend = "ssh";
    key = "~/.ssh/id_ed25519.pub";
    sign-all = true;
  };
  ui.diff-formatter = [ "delta" "$left" "$right" ];
};
```

---

## 8. `act` — run GitHub Actions locally

```nix
neusis.supercharged-git.tools.act.enable = true;
```

Needs a container runtime (Docker, Podman, OrbStack). Inside a repo
with `.github/workflows/`:

```sh
act -l                          # list workflows + jobs
act push                        # simulate a push event
act -j test                     # run just the `test` job
act --secret-file .secrets       # mount per-job secrets
act -P ubuntu-latest=catthehacker/ubuntu:act-22.04
                                 # pick a heavier image with more preinstalled
```

Cuts the "edit workflow → push → wait → fail → fix → push" loop down
to seconds.

---

## 9. `mergiraf` — semantic 3-way merge

```nix
neusis.supercharged-git.tools.mergiraf.enable = true;
```

This module installs the binary and registers a git merge driver
named `mergiraf`. To opt **specific paths** in, add to the repo's
`.gitattributes`:

```
# Use mergiraf for files where line-based merging makes a mess.
*.nix    merge=mergiraf
*.md     merge=mergiraf
*.json   merge=mergiraf
*.yaml   merge=mergiraf
```

Then `git merge` / `git rebase` on those paths uses mergiraf's
tree-aware merge instead of line-based. Conflicts that *would* have
fired with diff3 often resolve cleanly.

Manually run a merge across two branches:

```sh
git checkout main
git merge feature/auth          # mergiraf runs automatically for opted-in paths
# inspect what mergiraf changed
git diff --merge-base
```

---

## 10. `gitleaks` — secret scanner

```nix
neusis.supercharged-git.tools.gitleaks.enable = true;
```

Module just puts the binary on PATH. Wire it in via pre-commit (see
§4) to scan every commit, or run on demand:

```sh
gitleaks detect --source . -v   # scan current working tree
gitleaks protect --staged       # scan only staged hunks (fast)
gitleaks dir .                   # scan a path
```

CI bonus: `gitleaks-action` for GitHub. Locally, the pre-commit hook
shown in §4 catches secrets before they ever leave your machine.

---

## 11. `graphite` (`gt`) — stacked-PR workflow

```nix
neusis.supercharged-git.tools.graphite.enable = true;
```

Useful when one feature branches into a chain of small PRs that
depend on each other.

```sh
gt init                         # one-time per repo
gt create -m "auth: token shape"
# … edit, commit …
gt create -m "auth: refresh flow"
# … edit, commit …
gt stack submit                 # opens a PR per branch, links them
gt log                          # see the stack tree
gt sync                         # rebase the whole stack against trunk
```

The "moves" are `gt up` / `gt down` to walk the stack, `gt restack`
to rebase children after editing a parent, and `gt absorb` to drop
WIP changes into the right ancestor branch automatically.

---

## 12. Multi-account GitHub

```nix
neusis.supercharged-git.tools.multi-account = {
  enable = true;
  accounts = {
    work = {
      userName = "Ankur Kumar";
      userEmail = "ank@employer.com";
      sshKey = "~/.ssh/id_ed25519_work";
      signingKey = "~/.ssh/id_ed25519_work.pub";
      directories = [ "~/code/work" ];
      orgs = [ "my-employer" ];
    };
    personal = {
      userName = "ank";
      userEmail = "ank@example.com";
      sshKey = "~/.ssh/id_ed25519";
      directories = [ "~/code/personal" ];
      # No `orgs` ⇒ no URL rewriting; you'd clone personal repos
      # with the default github.com host (uses the umbrella's
      # signingKey + default ssh key).
    };
  };
};
```

What this wires up:

- **SSH host aliases**: `github.com-work` and `github.com-personal` in
  `~/.ssh/config`, each pinned to its own `IdentityFile` with
  `IdentitiesOnly yes` so only that key is offered during auth.
- **Per-directory git identity**: anything under `~/code/work/` gets
  the work `user.name`/`user.email`/`user.signingkey`. Anything under
  `~/code/personal/` gets the personal identity. Everywhere else
  falls back to the umbrella's defaults.
- **URL rewriting**: `git@github.com:my-employer/<repo>` is silently
  rewritten to `git@github.com-work:my-employer/<repo>` — so cloning
  via `gh repo clone my-employer/foo` or pasting an upstream URL just
  works with the right key, no alias to remember.

### Sanity check

```sh
# Confirm each alias auths with the right key.
ssh -T git@github.com-work
# Hi <work-user>! You've successfully authenticated…

ssh -T git@github.com-personal
# Hi <personal-user>! …

# Verify per-directory identity:
cd ~/code/work && git config user.email      # → ank@employer.com
cd ~/code/personal && git config user.email  # → ank@example.com
cd /tmp && git config user.email             # → umbrella default
```

### Cloning new repos

```sh
# Work repo. Org `my-employer` is in `orgs`, so URL rewriting picks
# the work alias automatically.
mkdir -p ~/code/work
cd ~/code/work
gh repo clone my-employer/internal-tool
# → resolves to git@github.com-work:my-employer/internal-tool

# Personal repo. No URL rewrite for your username; default ssh key
# (the umbrella's signingKey) is used.
mkdir -p ~/code/personal
cd ~/code/personal
gh repo clone myuser/dotfiles
```

### Migrating existing repos

Repos cloned before you enabled this module are still pinned to
`git@github.com:…`. Either re-clone them under the right directory,
or rewrite the remote:

```sh
cd ~/old-checkout-of-work-repo
git remote set-url origin git@github.com-work:my-employer/internal-tool
```

If the repo is already in a directory that matches an account's
`directories`, the new commit identity kicks in automatically — no
extra command needed.

### Caveats

- **`gh` CLI auth is separate per host.** `gh auth login` authenticates
  for a single host (defaults to `github.com`). Multiple accounts on
  the same host aren't natively supported by gh — you'll log in with
  one and use it everywhere from the CLI. SSH-key-based git
  operations (`git push`, `git clone`) keep using the right account
  via the SSH alias regardless of which `gh` identity is current.
- **`gitdir` matches a prefix.** Symlinks inside `~/code/work/` to
  repos *outside* it don't pick up the work identity. Keep the actual
  `.git` under the configured directory.
- **The umbrella's `signing.*` is the fallback.** If an account
  doesn't set `signingKey`, signing inside that account's directories
  uses the umbrella key. Usually fine; explicitly set per-account
  `signingKey` only if you genuinely want different signatures (e.g.
  YubiKey for work).

---

## 13. `gclb` — bare clones with worktrees

`gclb` ships with the umbrella; you don't enable it via a `tools.*`
option. The binary is built as a flake package
(`flake.packages.<system>.gclb`) and bundled into the umbrella's
`home.packages`.

### What it does

`gclb <url> [-l <location>]` performs the four-step bare-clone +
worktree bootstrap in one command:

1. `git clone --bare <url> <location>` (default `<repo>/.bare/`).
2. Writes a `.git` *file* next to the bare dir pointing at it
   (`gitdir: .bare`) so plain `git` commands work from `<repo>/`.
3. Adds the standard `+refs/heads/*:refs/remotes/origin/*` fetch
   refspec so `git fetch` populates remote-tracking branches.
4. Runs `git remote show origin`, discovers the default branch, and
   creates a worktree for it: `git worktree add <branch> <branch>`.

You end up with the layout:

```
my-repo/
├── .git              # one-line pointer: gitdir: .bare
├── .bare/            # the actual bare repo
└── main/             # checked-out worktree of the default branch
```

### Why this layout

Worktree-per-branch workflows scale much better than `git checkout`
back-and-forth: each branch lives in its own directory, no shared
working tree to stash/restore. The bare repo is the single source of
truth; the directories alongside are cheap, independent checkouts.

### Examples

```sh
# Vanilla — clones into ./repo-name/.bare and adds a worktree for
# the default branch.
gclb git@github.com:org/repo.git

# Custom location for the bare dir.
gclb git@github.com:org/repo.git -l ~/code/work/repo/.bare

# Common follow-up: add another worktree for a feature branch.
cd repo-name
git worktree add feature-x feature-x

# After you're done with that branch:
git worktree remove feature-x
```

Pair it with multi-account (§12): clone work repos under
`~/code/work/<repo>/` and they pick up the right identity + SSH
alias automatically.

---

## 14. Bootstrap repos with `gclb-sync`

```nix
neusis.supercharged-git.tools.bootstrap-repos = {
  enable = true;
  # location defaults to ${config.home.homeDirectory}/code
  repos = [
    # Bare URL → dest derived from the URL (here: "dotfiles").
    "git@github.com:ank/dotfiles.git"
    "git@github.com:work/internal-tool.git"

    # Explicit dest (may include slashes for nested layouts).
    {
      url = "https://github.com/upstream/samples.git";
      dest = "external/samples";
    }
  ];
  # autoRun = true;   # opt-in: clone on every home-manager switch
};
```

### What you get

- **A `gclb-sync` binary on PATH.** Generated per-user from the
  `repos` list above, with each repo wired to clone through the
  `gclb` package the umbrella already ships.
- **Idempotency.** Every entry's `<dest>/.bare/` is checked before
  cloning; already-cloned repos are skipped, so re-runs are cheap.
- **One-shot machine bootstrap.** Activate this config on a fresh
  laptop, run `gclb-sync` once, and every repo on the list lands in
  `<location>/<dest>/` with the standard bare+worktree layout.
- **No auto-run by default.** Cloning is network-dependent and slow;
  the script doesn't fire on `home-manager switch` unless you opt in
  with `autoRun = true`.

### A typical first-machine session

```sh
# Switch to the new config — gclb-sync gets installed.
home-manager switch

gclb-sync
# ==> Cloning git@github.com:ank/dotfiles.git -> /Users/ank/code/dotfiles
# ==> Cloning git@github.com:work/internal-tool.git -> /Users/ank/code/internal-tool
# ==> Cloning https://github.com/upstream/samples.git -> /Users/ank/code/external/samples
# Done.

# Subsequent runs are no-ops.
gclb-sync
# skip: dotfiles (already cloned)
# skip: internal-tool (already cloned)
# skip: external/samples (already cloned)
# Done.
```

### Custom destinations

The `dest` field accepts slashes, so you can group repos into
subdirectories without flattening everything into one level:

```nix
repos = [
  { url = "git@github.com:vendor/lib-a.git"; dest = "vendor/lib-a"; }
  { url = "git@github.com:vendor/lib-b.git"; dest = "vendor/lib-b"; }
  { url = "git@github.com:work/app.git";     dest = "work/app"; }
];
```

`gclb-sync` creates intermediate directories as needed.

### Hands-free mode

```nix
neusis.supercharged-git.tools.bootstrap-repos.autoRun = true;
```

`gclb-sync` runs as a home-manager activation step (after the
write-boundary), so every `home-manager switch` reconciles the clone
list. Individual clone failures don't abort activation — they're
logged to stderr and you can re-run `gclb-sync` to retry.

### Pairing with multi-account (§12)

`location` is just a path. To get account-correct identity on the
cloned repos, point it at one of the directories covered by an
account's `directories`:

```nix
neusis.supercharged-git.tools = {
  multi-account.accounts.work.directories = [ "/Users/ank/code/work" ];

  bootstrap-repos = {
    enable = true;
    location = "/Users/ank/code/work";
    repos = [ "git@github.com:work-org/internal.git" ];
  };
};
```

Now every repo bootstrapped under `/Users/ank/code/work/` picks up
the work git identity automatically via `includeIf gitdir:`.

---

## Putting it all together — a typical config

What `ank` on `rogue` might actually run:

```nix
neusis.supercharged-git = {
  enable = true;
  userName = "Ankur Kumar";
  userEmail = "ank@bodygram.com";
  allowedSignersPubkey = "ssh-ed25519 AAAA…";

  tools = {
    gh.enable = true;
    lazygit.enable = true;
    delta.enable = true;
    pre-commit.enable = true;
    commitizen.enable = true;
    jujutsu.enable = true;
    gitleaks.enable = true;
    multi-account = {
      enable = true;
      accounts.work = {
        userName = "Ankur Kumar";
        userEmail = "ank@bodygram.com";
        sshKey = "~/.ssh/id_ed25519_work";
        directories = [ "~/code/work" ];
        orgs = [ "bodygram" ];
      };
    };
    bootstrap-repos = {
      enable = true;
      repos = [
        "git@github.com:ank/dotfiles.git"
        { url = "git@github.com:bodygram/main.git"; dest = "work/main"; }
      ];
    };
    # act, mergiraf, graphite stay off until needed
  };
};
```

A normal day after `home-manager switch`:

```sh
cd ~/code/work-repo
lazygit                         # stage & commit interactively
# … work …
gh pr create --fill --web       # send for review
gh dash                         # check what's waiting on me
# CI fails on a workflow change:
act -j lint                     # reproduce locally
git commit --amend
gh pr checks --watch            # back in the green
```

---

## Where to go next

- Each tool's upstream docs are far more detailed than this — check
  them when you want a specific feature.
- `pre-commit` hook ideas worth stealing: `nix flake check`,
  `treefmt`, `nixfmt-rfc-style`, `statix`, `deadnix`.
- For jj specifically, the
  [jj tutorial](https://github.com/martinvonz/jj/blob/main/docs/tutorial.md)
  is the fastest on-ramp once you've enabled the module.
