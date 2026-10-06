# supercharged-shell — tutorial

A walkthrough of the `neusis.supercharged-shell` umbrella and the
nine tool sub-modules that ship under it: an opinionated terminal
developer toolkit with a TUI file manager, env auto-loader, two
fuzzy pickers, three nix-aware helpers, a smarter `cd`, and
syncable shell history.

Sister to [`supercharged-git`](../supercharged-git/tutorial.md) and
[`terminal-velocity`](../terminal-velocity/tutorial.md) — designed
to be enabled together without overlap.

Import the umbrella into one of your home-manager bundles:

```nix
imports = [ self.homeModules.supercharged-shell ];
```

Importing the umbrella declares every
`neusis.supercharged-shell.tools.*` option but enables none — you opt
in piecemeal.

---

## 0. CLI utility bundle

```nix
neusis.supercharged-shell.enable = true;
```

This is the umbrella-level toggle. It installs a curated bundle of
general-purpose CLI utilities and developer toolchains into
`home.packages`, regardless of which `tools.*` sub-modules you also
enable:

- **General CLI**: `bat`, `bottom`, `chafa`, `comma`, `duf`, `eza`,
  `fd`, `gdu`, `htop`, `imagemagick`, `nix-output-monitor`, `ouch`,
  `rclone`, `ripgrep`, `unzip`, `wget`, `xclip`.
- **Toolchains**: `cargo`, `clang`, `clang-tools`, `cmake`, `deno`,
  `gnumake`, `ninja`, `nodejs_22`, `python3`, `rustc`,
  `texliveFull`.
- **Lua** (for yazi plugins / wezterm config / neovim configs):
  `lua51Packages.lua`, `lua51Packages.luarocks`.
- **Linux-only**: `sioyek` (PDF viewer; doesn't build on Darwin).

The bundle is independent of `tools.*` — you can enable individual
tool sub-modules without the bundle, and vice versa.

Extend without forking the bundle:

```nix
neusis.supercharged-shell = {
  enable = true;
  extraPackages = with pkgs; [ jq yq tealdeer ];
};
```

Want fewer than the curated set? Leave the umbrella `enable` off and
manage `home.packages` yourself; cherry-pick the tool sub-modules
below for the program-level config.

---

## 1. `yazi` — TUI file manager

```nix
neusis.supercharged-shell.tools.yazi.enable = true;
```

Ships with:

- Zsh and bash integration (`y` shell function that `cd`s to the
  yazi-exited directory).
- Hidden files visible by default.
- Large image previews (max 2000×2000) — great for image-heavy
  directories.
- A bundled `max-preview` plugin: press `T` inside yazi to toggle
  the preview pane to full width and back.

```sh
yazi               # or `y` if you want shell-side cd-on-exit
```

Useful keys (yazi already ships sensible defaults; these are the
ones worth remembering):

| Key | Action |
|---|---|
| `j` / `k` | Up/down (vim) |
| `h` / `l` | Parent / enter |
| `space` | Select |
| `T` (custom) | Toggle full-screen preview |
| `o` | Open with system default |
| `?` | Help |

Override the package if you want a pinned or unstable yazi:

```nix
neusis.supercharged-shell.tools.yazi.package = pkgs.unstable.yazi;
```

---

## 2. `direnv` — per-project env auto-loading

```nix
neusis.supercharged-shell.tools.direnv.enable = true;
```

Enables `direnv` + `nix-direnv` with zsh integration. The
`nix-direnv` plumbing caches `use flake` / `use nix` evaluations so
re-entering a project directory doesn't re-evaluate the whole
flake.

Typical per-project setup:

```sh
cd ~/code/some-project
echo 'use flake' > .envrc
direnv allow
# now: cd in/out auto-activates/deactivates the dev shell.
```

The cache lives under `.direnv/`; add it to `.gitignore`.

---

## 3. `fzf` — fuzzy finder + shell widgets

```nix
neusis.supercharged-shell.tools.fzf.enable = true;
```

Enables `programs.fzf` with zsh integration, the "full" UI style,
and a `bat`-backed file preview for the Ctrl-T widget.

Out-of-the-box zsh keybindings:

| Key | What it does |
|---|---|
| `Ctrl-T` | Fuzzy-pick a file/dir and paste its path |
| `Ctrl-R` | Fuzzy-search command history |
| `Alt-C` | Fuzzy-pick a dir and `cd` into it |

```sh
# Pipe anything into fzf for ad-hoc filtering:
git log --oneline | fzf
nix flake show --json | jq -r '.nixosConfigurations | keys[]' | fzf
```

Override the UI/preview if `--style full` is too busy or you want
something other than `bat`:

```nix
neusis.supercharged-shell.tools.fzf = {
  enable = true;
  defaultOptions = [ "--height=40%" "--reverse" ];
  fileWidgetOptions = [ "--preview='head -200 {}'" ];
};
```

---

## 4. `television` (`tv`) — channel-based fuzzy picker

```nix
neusis.supercharged-shell.tools.television.enable = true;
```

`tv` is a younger fuzzy picker organized around *channels* — named
sources (files, processes, git branches, nixpkgs results …). Pair
it with `nix-search-tv` (§5) for a one-keystroke jump into the
nixpkgs catalogue.

```sh
tv                 # default channel picker
tv files           # files channel
tv processes       # processes channel
```

Zsh keybinding integration is **off by default** because fzf wants
the same `Ctrl-R`/`Ctrl-T` keys. Pick one. Turn `tv`'s on (and
fzf's off, in §3) if you want to drive the shell with tv instead:

```nix
neusis.supercharged-shell.tools.television.enableZshIntegration = true;
```

The default package is `pkgs.television`. Bleeding-edge features
live in `pkgs.unstable.television` (requires the `unstable`
overlay):

```nix
neusis.supercharged-shell.tools.television.package = pkgs.unstable.television;
```

---

## 5. `nix-search-tv` — nixpkgs/options channel for `tv`

```nix
neusis.supercharged-shell.tools.nix-search-tv.enable = true;
```

Adds three channels to television:

- `nixpkgs` — search packages.
- `nixos-options` — search NixOS module options.
- `home-manager-options` — search home-manager module options.

```sh
tv nixpkgs                 # type `ripgrep` → see package metadata, version, …
tv nixos-options           # type `services.openssh` → option details
tv home-manager-options    # type `programs.git` → home-manager docs
```

Needs the `television` tool to actually be useful — enable both.

---

## 6. `nix-your-shell` — keep your shell inside `nix-shell`

```nix
neusis.supercharged-shell.tools.nix-your-shell.enable = true;
```

`nix-shell` and `nix develop` normally drop you into bash regardless
of your login shell. `nix-your-shell` patches that so you stay in
zsh inside the dev env — preserving your aliases, prompt, history,
and (importantly) your existing `direnv` hooks.

Transparent — once enabled, just run `nix-shell` / `nix develop`
as usual.

---

## 7. `nix-init` — derivation scaffolder

```nix
neusis.supercharged-shell.tools.nix-init = {
  enable = true;
  maintainers = [ "ank" ];   # your nixpkgs handle
};
```

Generates a packaging-ready Nix expression from an upstream release
URL. Handles common build systems out of the box (autoconf, cmake,
cargo, go, python, …).

```sh
nix-init -u https://github.com/some/project/archive/v1.2.3.tar.gz
# → prompts a few times (license, mainProgram, …), then writes
#   default.nix in the current dir.
```

The `maintainers` option pre-fills `meta.maintainers` so you don't
type your nixpkgs handle each time.

---

## 8. `atuin` — encrypted, syncable shell history

```nix
neusis.supercharged-shell.tools.atuin.enable = true;
```

Replaces zsh's history file with atuin's SQLite-backed,
end-to-end-encrypted store, syncable across machines. Owns
`Ctrl-R` (fuzzy search across all hosts you've authenticated). The
default `--disable-up-arrow` flag keeps vanilla zsh history-up
working unchanged.

First-run setup (per host):

```sh
atuin register -u <user> -e <email>     # or: atuin login -u <user>
atuin sync                              # backfill from / to server
```

Defaults sync every 5 minutes against the public atuin.sh server.
Self-hosting? Override `sync_address`:

```nix
neusis.supercharged-shell.tools.atuin = {
  enable = true;
  settings = {
    auto_sync = true;
    sync_frequency = "5m";
    sync_address = "https://atuin.my-domain.example";
    search_mode = "fuzzy";
    enter_accept = false;        # require Tab to inject, Enter to run
  };
};
```

Drop the `--disable-up-arrow` flag if you'd rather atuin own the
up-arrow too:

```nix
neusis.supercharged-shell.tools.atuin.flags = [ ];
```

---

## 9. `zoxide` — smarter `cd`

```nix
neusis.supercharged-shell.tools.zoxide.enable = true;
```

Replaces `cd` with frecency-ranked directory jumping. After zoxide
has seen you visit a dir a few times:

```sh
z proj             # jumps to ~/code/work/some-project (highest match)
z work proj        # multiple substrings — narrows the match
zi                 # interactive picker (fzf-style) over your jump list
```

Both bash and zsh integration are on by default. `cd` itself is
unchanged; `z` is the smarter sibling.

---

## Putting it all together — a typical config

A reasonable starting point for a daily-driver workstation:

```nix
imports = [
  self.homeModules.supercharged-git
  self.homeModules.supercharged-shell
  self.homeModules.terminal-velocity
];

neusis.supercharged-git = {
  enable = true;
  userName = "Ankur Kumar";
  userEmail = "ank@example.com";
  tools = {
    gh.enable = true;
    lazygit.enable = true;
    delta.enable = true;
    pre-commit.enable = true;
    commitizen.enable = true;
    jujutsu.enable = true;
  };
};

neusis.supercharged-shell = {
  # Umbrella bundle: eza/bat/ripgrep/htop/comma/… on PATH.
  enable = true;

  tools = {
    yazi.enable = true;
    direnv.enable = true;
    fzf.enable = true;
    zoxide.enable = true;
    nix-your-shell.enable = true;
    atuin.enable = true;
    # If you want the tv ecosystem too:
    # television.enable = true;
    # nix-search-tv.enable = true;
    # nix-init = { enable = true; maintainers = [ "ank" ]; };
  };
};

neusis.terminal-velocity.tools = {
  wezterm.enable = true;
  kitty.enable = true;
  zellij.enable = true;
};
```

A typical session afterwards:

```sh
z proj                          # zoxide jump
direnv  # … envrc auto-loads    # → dev shell active
y                               # yazi to explore the tree
# back in shell after yazi exit (zsh integration cd's for you):
git status                       # delta renders diffs
gh pr create --fill --web        # supercharged-git's gh tool
lazygit                          # supercharged-git's lazygit tool
```

---

## Overlap with sister umbrellas

The three umbrellas are designed to be enabled side-by-side. Each
tool lives in exactly one of them — if you find yourself reaching
for `programs.<x>` directly in a bundle, check whether one of these
already exposes it.

| Tool | Umbrella |
|---|---|
| `gh`, `gh-dash`, `lazygit`, `delta`, `pre-commit`, `commitizen`, `jujutsu`, `act`, `mergiraf`, `gitleaks`, `multi-account`, `bootstrap-repos`, `gclb` | supercharged-git |
| `direnv`, `zoxide`, `fzf`, `tv`, `nix-search-tv`, `nix-your-shell`, `nix-init`, `yazi`, `atuin` | supercharged-shell |
| `wezterm`, `kitty`, `zellij`, `tmux`, `sesh`, `mosh`, `eternal-terminal` | terminal-velocity |
| `claude-code`, `opencode`, `gemini-cli`, `pi`, `hermes`, `agent-deck`, `beads`, `beads-viewer`, `spec-kit`, `skills`, `qmd` | agent-harness |
| `paperwm`, `activespace` (macOS-only window tiling) | hammerspoon |

---

## Where to go next

- Each tool's upstream docs cover knobs we don't expose. Override
  via `programs.<tool>.<...>` after enabling — home-manager's
  options merge with ours.
- `tv` and `fzf` solve the same problem differently. Run both for
  a week, pick the one you reach for more often, disable the other.
- `nix-your-shell` + `direnv` is the "I never thought about my
  shell again" combo. Worth setting up early.
