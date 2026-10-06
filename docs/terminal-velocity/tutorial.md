# terminal-velocity — tutorial

Physics pun: max speed of a falling object. Practically: the
home-manager umbrella for terminal emulators, multiplexers, and
remote-shell clients. Seven opt-in tool sub-modules:

- `wezterm` — GPU-accelerated emulator with a Lua config.
- `kitty`   — second emulator (handy as a fallback, esp. on macOS).
- `zellij`  — modern multiplexer (tmux alternative).
- `tmux`    — classic multiplexer with the vim-tmux-navigator /
              resurrect / continuum / popup-toggle plugin set.
- `sesh`    — tmux session orchestrator (fuzzy session picker).
- `mosh`    — UDP-based SSH replacement (roaming, sleep/wake).
- `eternal-terminal` — TCP-based SSH replacement (firewall-friendly).

Sister to [`supercharged-git`](../supercharged-git/tutorial.md) and
[`supercharged-shell`](../supercharged-shell/tutorial.md). No
overlap — these three umbrellas can all be enabled together.

Import the umbrella into one of your home-manager bundles:

```nix
imports = [ self.homeModules.terminal-velocity ];
```

Importing declares every
`neusis.terminal-velocity.tools.*` option but enables none — opt in
piecemeal. There's no umbrella-level `enable`; each tool stands on
its own.

---

## 1. `wezterm`

```nix
neusis.terminal-velocity.tools.wezterm.enable = true;
```

Enables `programs.wezterm` with the bundled `wezterm.lua` (shipped
next to the module) as the runtime config. Shell integration is
off — wezterm's shell-side helpers conflict with most setups, so
this is the lower-surprise default.

Override the Lua config with your own:

```nix
neusis.terminal-velocity.tools.wezterm.extraConfig =
  builtins.readFile ./my-wezterm.lua;
```

Override the package (e.g. nightly):

```nix
neusis.terminal-velocity.tools.wezterm.package = pkgs.wezterm-nightly;
```

---

## 2. `kitty`

```nix
neusis.terminal-velocity.tools.kitty.enable = true;
```

Minimal-chrome kitty:

- `hide_window_decorations`:
  - **Darwin** → `titlebar-only` (macOS still needs *something* to
    drag/close the window).
  - **Linux** → `yes` (full borderless).
- `draw_minimal_borders = yes` — no thick inner borders between
  splits.

Extend via `extraSettings`, which merges on top of the defaults:

```nix
neusis.terminal-velocity.tools.kitty.extraSettings = {
  font_size = 13;
  background_opacity = "0.95";
  cursor_blink_interval = "0";
};
```

---

## 3. `zellij`

```nix
neusis.terminal-velocity.tools.zellij.enable = true;
```

Enables `programs.zellij` with:

- `theme = "gruvbox-dark"`
- `simplified_ui = true` — pares down the status bar.
- `default_mode = "locked"` — zellij's keymaps don't grab your
  prefix until you unlock with `Ctrl-g`. Means zellij can run
  inside another zellij/tmux without key conflicts.

Also writes two config files via `xdg.configFile`:

- `~/.config/zellij/config.kdl` — full keymap + UI config.
- `~/.config/zellij/layouts/default.kdl` — the default layout
  loaded on `zellij`.

Override one or both:

```nix
neusis.terminal-velocity.tools.zellij = {
  enable = true;
  configFile = ./my-zellij-config.kdl;
  defaultLayout = ./my-layout.kdl;
  # Or null to skip writing one entirely:
  # defaultLayout = null;
};
```

`settings` is also overridable (it controls the values zellij reads
from its own startup config — separate from the kdl file):

```nix
neusis.terminal-velocity.tools.zellij.settings = {
  theme = "tokyo-night";
  simplified_ui = false;
  default_mode = "normal";
};
```

### Quick zellij keymap reference (default mode unlocked)

| Keys | What |
|---|---|
| `Ctrl-g` | Toggle lock (must be unlocked to send other commands) |
| `Ctrl-p` then `r/d/u/l` | Resize pane right/down/up/left |
| `Ctrl-p` then `n` | New pane |
| `Ctrl-t` then `n` | New tab |
| `Ctrl-s` then `s` | Scroll mode (vim-style nav) |

(Bound by the bundled `config.kdl` — see the file for the full set.)

---

## 4. `tmux`

```nix
neusis.terminal-velocity.tools.tmux.enable = true;
```

Defaults:

- `prefix = "C-b"` (configurable).
- `terminal = "tmux-256color"`, `mouse = true`.
- `shell` = `${pkgs.zsh}/bin/zsh` (configurable via `shellPath`).
- Bundled plugins:
  - **vim-tmux-navigator** + vi mode-keys + `h/j/k/l` pane
    navigation under the prefix.
  - **resurrect** with `@resurrect-strategy-nvim 'session'` and
    pane-contents capture.
  - **continuum** with `@continuum-restore 'on'`,
    `@continuum-boot 'on'`, 10-minute save interval, wezterm boot.
  - **better-mouse-mode** + **tmux-toggle-popup**.
- Popup bindings under the prefix:

  | Key | Pops up |
  |---|---|
  | `t` | A scratch shell |
  | `y` | yazi |
  | `g` | lazygit |
  | `m` | rmpc |
  | `a` | agent-deck |
  | `p` | ipython |

  The popups assume the corresponding binaries exist on PATH —
  enable `supercharged-shell.tools.yazi`,
  `supercharged-git.tools.lazygit`, etc. to make sure they do.
- Inside the popup tmux server, copy commands re-route through the
  main server so clipboard is shared.
- Extra binding: `prefix + L` runs `sesh last`,
  `prefix + R` re-sources `~/.config/tmux/tmux.conf`.

When `supercharged-shell.tools.fzf` is also enabled, fzf's tmux
shell integration is wired up automatically (`Ctrl-T` inside tmux
pops fzf for path injection).

Override the prefix or shell:

```nix
neusis.terminal-velocity.tools.tmux = {
  enable = true;
  prefix = "C-a";
  shellPath = "${pkgs.fish}/bin/fish";
};
```

---

## 5. `sesh`

```nix
neusis.terminal-velocity.tools.sesh = {
  enable = true;
  tmuxKey = "s";                            # prefix + s opens the picker
};
```

Fuzzy-pick or create a tmux session. Works standalone too:

```sh
sesh list                  # all sessions and project candidates
sesh connect work          # attach to (or create) "work"
sesh last                  # toggle to the previously-active session
```

The legacy config pinned to `pkgs.unstable.sesh` for newer
features; if you want that, override the package (requires the
`unstable` overlay):

```nix
neusis.terminal-velocity.tools.sesh = {
  enable = true;
  package = pkgs.unstable.sesh;
};
```

Pair with `tools.tmux` for the in-tmux prefix binding; standalone
sesh works without tmux but loses the keybinding.

---

## 6. `mosh`

```nix
neusis.terminal-velocity.tools.mosh.enable = true;
```

Installs the `mosh` client. UDP-based SSH replacement — survives
roaming networks, sleep/wake cycles, and lousy latency. Drop-in
for `ssh`:

```sh
mosh user@host
```

This module only installs the client. The remote host needs
`mosh-server` available too (usually `apt install mosh` or
`nix-env -iA nixpkgs.mosh` on the server side, depending on the
target).

---

## 7. `eternal-terminal` (`et`)

```nix
neusis.terminal-velocity.tools.eternal-terminal.enable = true;
```

Like mosh but TCP-based — friendlier to corporate firewalls that
block outbound UDP. Listens on TCP/2022 by default. Preserves
tmux/scrollback across reconnects.

```sh
et user@host                              # default port 2022
et -p 4422 user@host                      # custom port
```

This module only installs the client. The server side needs
`etserver` running, typically as a system service. Mutually useful
with mosh — pick whichever your target host has.

---

## Putting it all together

```nix
imports = [
  self.homeModules.supercharged-git
  self.homeModules.supercharged-shell
  self.homeModules.terminal-velocity
];

neusis.terminal-velocity.tools = {
  wezterm.enable = true;
  kitty.enable = true;
  # Pick one multiplexer (or both — they don't fight):
  tmux.enable = true;
  sesh.enable = true;
  # zellij.enable = true;

  # Remote-shell clients:
  mosh.enable = true;
  eternal-terminal.enable = true;
};
```

A reasonable workflow:

- Launch a session with wezterm or kitty.
- Inside, `tmux` (then `prefix + s` for sesh's session picker) or
  `zellij` for the modern alternative.
- For long-running remote sessions, `mosh user@host` (or
  `et user@host` behind firewalls).

---

## Overlap with sister umbrellas

| Tool | Umbrella |
|---|---|
| `gh`, `gh-dash`, `lazygit`, `delta`, `pre-commit`, `commitizen`, `jujutsu`, `act`, `mergiraf`, `gitleaks`, `multi-account`, `bootstrap-repos`, `gclb` | supercharged-git |
| `direnv`, `zoxide`, `fzf`, `tv`, `nix-search-tv`, `nix-your-shell`, `nix-init`, `yazi`, `atuin` | supercharged-shell |
| `wezterm`, `kitty`, `zellij`, `tmux`, `sesh`, `mosh`, `eternal-terminal` | terminal-velocity (this umbrella) |
| `claude-code`, `opencode`, `gemini-cli`, `pi`, `hermes`, `agent-deck`, `beads`, `beads-viewer`, `spec-kit`, `skills`, `qmd` | agent-harness |
| `paperwm`, `activespace` (macOS-only window tiling) | hammerspoon |

---

## Why both wezterm *and* kitty?

Mostly redundancy. On macOS, GPU-accelerated emulators occasionally
hit driver weirdness on a particular update; having a second one
already configured saves a panic-troubleshooting hour. Linux users
who only need one can disable the other.

`programs.wezterm` and `programs.kitty` write to different config
directories (`~/.config/wezterm/` vs `~/.config/kitty/`), so
enabling both doesn't fight.

---

## Where to go next

- Wezterm's Lua config has a lot more knobs than this module
  exposes — read [the manual](https://wezfurlong.org/wezterm/) and
  shovel anything you want into `extraConfig`.
- Zellij plugins live under `~/.config/zellij/plugins/`. If you
  start customizing keymaps heavily, fork the bundled `config.kdl`
  and point `configFile` at your fork.
- For tmux refugees: zellij's locked-mode default is the biggest
  adjustment. Once `Ctrl-g` is muscle memory, the rest of the
  keymap is familiar.
