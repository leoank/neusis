# hammerspoon — tutorial

A walkthrough of the `neusis.hammerspoon` home-manager module: a
**macOS-only** opt-in that links a bundled hammerspoon config
(PaperWM tiling + ActiveSpace + SpoonInstall) into
`~/.hammerspoon/`. No-op on Linux.

Sister to the four umbrella modules
([`supercharged-git`](../supercharged-git/tutorial.md),
[`supercharged-shell`](../supercharged-shell/tutorial.md),
[`terminal-velocity`](../terminal-velocity/tutorial.md),
[`agent-harness`](../agent-harness/tutorial.md)) — no tool overlap;
all five can be enabled side-by-side.

---

## 0. Install hammerspoon itself

This module **does not install hammerspoon** — hammerspoon is a
macOS GUI app, not a CLI. Install it once via your nix-darwin
config:

```nix
homebrew.casks = [ "hammerspoon" ];
```

…or as a one-off:

```sh
brew install --cask hammerspoon
```

After install: open the app once, grant Accessibility permissions in
*System Settings → Privacy & Security → Accessibility*, and check
*Launch Hammerspoon at login* in its preferences.

---

## 1. Enable the module

Import in any home-manager bundle, then enable:

```nix
imports = [ self.homeModules.hammerspoon ];

neusis.hammerspoon.enable = true;
```

That links the bundled `init.lua` and `Spoons/` directory into
`~/.hammerspoon/`. Reload hammerspoon (menubar → *Reload Config*,
or `hs.reload()` in the console) to pick up the change.

The config is guarded by `pkgs.stdenv.isDarwin` — enabling it on
a Linux host is a no-op, not an error. Safe to leave on in a
cross-platform bundle.

---

## 2. What ships in the bundle

- **`init.lua`** — wires up the spoons below, defines hotkeys,
  and starts PaperWM with `screen_margin = 16`, `window_gap = 2`.
- **`Spoons/SpoonInstall.spoon/`** — spoon dependency manager
  (used to pull PaperWM from its release branch).
- **`Spoons/PaperWM.spoon/`** — tiled-grid window manager.
  Vendored from
  [mogenson/PaperWM.spoon](https://github.com/mogenson/PaperWM.spoon)
  (release branch).
- **`Spoons/ActiveSpace.spoon/`** — exposes the current Mission
  Control space; PaperWM uses it to track per-space tiling.

The vendored spoons are pinned in the repo (not auto-updated via
`SpoonInstall:andUse`), so the config is fully reproducible.

---

## 3. Keymap quick reference

All bindings under `⌥⌘` (option + command) unless noted.

### PaperWM — focus

| Keys | Action |
|---|---|
| `⌥⌘ ←/→/↑/↓` | Focus left/right/up/down |
| `⌥⌘ j` | Focus next window |
| `⌥⌘ k` | Focus previous window |
| `⌘⇧ 1`–`9` | Focus window 1–9 in current space |

### PaperWM — move / swap

| Keys | Action |
|---|---|
| `⌥⌘⇧ ←/→/↑/↓` | Swap window with neighbour |
| `⌥⌘ i` | Slurp focused window into the column on the left |
| `⌥⌘ o` | Barf focused window out of its column to the right |
| `⌥⌘⇧ Esc` | Toggle floating (in/out of the tiling layer) |

### PaperWM — resize

| Keys | Action |
|---|---|
| `⌥⌘ c` | Center window |
| `⌥⌘ f` | Full width |
| `⌥⌘ r` | Cycle width presets |
| `⌃⌥⌘ r` | Reverse cycle width |
| `⌥⌘⇧ r` | Cycle height presets |
| `⌃⌥⌘⇧ r` | Reverse cycle height |
| `⌥⌘ l` | Increase width |
| `⌥⌘ h` | Decrease width |

### Spaces

| Keys | Action |
|---|---|
| `⌥⌘ ,` / `⌥⌘ .` | Switch space left / right |
| `⌥⌘ 1`–`9` | Switch to space 1–9 |
| `⌥⌘⇧ 1`–`9` | Move focused window to space 1–9 |

### Modal hjkl layer

`⌘ Return` enters a modal layer where `h/j/k/l` move focus
(vim-style), `Esc` exits. Handy if you don't want to hold
`⌥⌘` constantly.

---

## 4. Swap in your own config

Point `configDir` at any directory containing your own `init.lua`
(and optionally a `Spoons/` subdirectory):

```nix
neusis.hammerspoon = {
  enable = true;
  configDir = ./my-hammerspoon;
};
```

Whatever's at that path is linked verbatim into `~/.hammerspoon/`.
Bundled spoons are dropped if your dir doesn't include them.

---

## 5. Editing the bundled config in place

Because `home.file."<...>".source = ./.` symlinks into the Nix
store, you **can't edit `~/.hammerspoon/init.lua` directly** — it's
read-only. The supported flow is:

1. Edit the source: `new_modules/homeModules/hammerspoon/init.lua`.
2. `git add` the change.
3. `home-manager switch --flake .#<user>@<host>`.
4. Hammerspoon menubar → *Reload Config* (or `hs.reload()`).

For iterative tweaking, copy the bundled dir somewhere writable and
point `configDir` at the copy:

```nix
neusis.hammerspoon = {
  enable = true;
  configDir = "${config.home.homeDirectory}/dotfiles/hammerspoon";
};
```

Once you're happy, fold the changes back into `init.lua` and switch
back to the default.

---

## 6. Troubleshooting

- **Bindings don't fire.** Open *System Settings → Privacy &
  Security → Accessibility* and make sure hammerspoon is checked.
  macOS revokes the grant on app version changes occasionally.
- **PaperWM mis-tiles after sleep/wake.** `hs.reload()` from the
  hammerspoon console usually fixes it. If you hit it daily, look
  into `ActiveSpace` event hooks in the spoon.
- **Spoons not found.** Check the symlink:
  `readlink ~/.hammerspoon` should point into `/nix/store/`. If it
  doesn't, the module isn't enabled or `home-manager switch` didn't
  run.
- **`MJConfigFile` preference.** Hammerspoon honours a
  `MJConfigFile` user-default that overrides `~/.hammerspoon/`.
  If you've set it via `defaults write org.hammerspoon.Hammerspoon
  MJConfigFile`, this module's symlink is ignored. Clear the
  preference or set `configDir` to match its value.

---

## 7. Where to go next

- [PaperWM.spoon docs](https://github.com/mogenson/PaperWM.spoon)
  — every hotkey is configurable; edit `bindHotkeys` in
  `init.lua`.
- [Hammerspoon Spoons index](https://www.hammerspoon.org/Spoons/)
  — drop additional spoons into `Spoons/` next to the bundled
  ones and they'll auto-ship.
- The bundled `init.lua` is ~125 lines and self-contained — read
  it top-to-bottom before adding more.
