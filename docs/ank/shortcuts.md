# Shortcuts

## Machines

| Machine | OS | Username | tmux | zsh | hammerspoon | kitty | nvim |
|---------|----|----------|------|-----|-------------|-------|------|
| darwin001 | macOS | kumarank | yes | yes | yes | yes | yes |
| rogue | macOS | ank | yes | yes | yes | yes | yes |
| oppy | Linux | ank | no | yes | no | yes | yes |
| karkinos | Linux | ank | no | yes | no | yes | yes |
| chiral | Linux/WSL | ank | no | no | no | yes | no |

---

## tmux

Config: `homes/ank/configs/tmux.nix`
Used on: darwin001, rogue

| Shortcut | Action |
|----------|--------|
| `C-b` | Prefix |
| `C-b h/j/k/l` | Select pane (left/down/up/right) via vim-tmux-navigator |
| `C-b L` | Launch sesh (session selector) |
| `C-b t` | Toggle scratch terminal popup |
| `C-b g` | Toggle lazygit popup |
| `C-b a` | Toggle agentdeck popup |
| `C-b s` | sesh tmux key binding |

Plugins: resurrect (auto-save nvim sessions), continuum (auto-save every 10min, auto-restore on boot), better-mouse-mode, toggle-popup.

---

## Zsh (ank config with vi-mode)

Config: `homes/ank/configs/zsh.nix`
Used on: darwin001, rogue, oppy, karkinos

| Shortcut / Command | Action |
|---------------------|--------|
| `^R` (insert/cmd) | atuin-search (search shell history) |
| `oc` | opencode |
| `ll` | `eza -lah --color-scale=all --hyperlink` |
| `lt` | `eza -l --git --git-repos --tree --level=2` |
| `n` | `nvim` |
| `nvt` | `nvim +terminal` |
| `ns` | `nix search nixpkgs` |
| `cat` | bat (alias) |
| `df` | duf (alias) |
| `G` | global alias: pipe to `grep --color=auto -i -n` |
| `nz <query>` | zoxide jump to dir then open nvim |
| `nx <pkgs>` | `nix-shell -p <pkgs>` |
| `nxp <pkgs>` | nix-shell with python packages |
| `nxpc <pkgs>` | nix-shell with python + cuda support |

zsh-vi-mode is enabled. `KEYTIMEOUT=30`. `ZVM_VI_EDITOR=nvim`.

---

## Hammerspoon / PaperWM

Config: `homes/ank/configs/hammerspoon/init.lua`
Used on: darwin001, rogue

### PaperWM Hotkeys

Modifier `alt+cmd` is the primary chord.

| Shortcut | Action |
|----------|--------|
| `alt+cmd + arrows` | Focus window in direction |
| `alt+cmd + j/k` | Focus next/prev window (cycle) |
| `alt+cmd+shift + arrows` | Swap window in direction |
| `alt+cmd + c` | Center focused window |
| `alt+cmd + f` | Full width toggle |
| `alt+cmd + r` | Cycle width |
| `ctrl+alt+cmd + r` | Reverse cycle width |
| `alt+cmd+shift + r` | Cycle height |
| `ctrl+alt+cmd+shift + r` | Reverse cycle height |
| `alt+cmd + l/h` | Increase/decrease width |
| `alt+cmd + i/o` | Slurp in / barf out (move in/out of column) |
| `alt+cmd+shift + escape` | Toggle floating |
| `cmd+shift + 1-9` | Focus window N in current space |
| `alt+cmd + ,/.` | Switch to prev/next Mission Control space |
| `alt+cmd + 1-9` | Switch to space N |
| `alt+cmd+shift + 1-9` | Move window to space N |

### Modal Layer

| Shortcut | Action |
|----------|--------|
| `cmd+enter` | Enter modal layer |
| `h/j/k/l` | Focus left/down/up/right |
| `escape` | Exit modal layer |

---

## Kanata (Home Row Mods)

Config: `homes/ank/configs/custom.kbd`
Used on: darwin001, rogue

Base layer function row: `brdn brup _ _ _ _ prev pp next mute vold volu`

Home row mods (QWERTY):

| Key | Tap | Hold |
|-----|-----|------|
| `a` | a | Left Meta (Cmd) |
| `s` | s | Left Alt |
| `d` | d | Left Ctrl |
| `f` | f | Left Shift |
| `j` | j | Right Shift |
| `k` | k | Right Ctrl |
| `l` | l | Right Alt |
| `;` | ; | Right Meta (Cmd) |

Tap-hold timing: index 200ms, middle 230ms, ring 260ms, pinky 290ms.

---

## Kitty

Config: `homes/common/dev/terminals.nix`
Used on: all machines

| Setting | Value (Linux / macOS) |
|---------|-----------------------|
| Hide decorations | `yes` / `titlebar-only` |
| Minimal borders | `yes` |

---

## Neovim (kalamv2)

Config: `pkgs/kalamv2/`
Used on: darwin001, rogue, oppy, karkinos

Leader key: `Space`

### Core

| Shortcut | Action |
|----------|--------|
| `<Space><Space>` | Save file |
| `<Space>qq` | Quit all |
| `<esc>` | Clear search highlight (`:noh`) |
| `n` / `N` | Search next/prev (centered) |
| `<C-a>` (insert) | Select all |
| `<leader>y` | Copy to system clipboard |
| `<leader>D` | Delete to void register |

### Toggle UI Options

| Shortcut | Action |
|----------|--------|
| `<Space>ul` | Toggle line numbers |
| `<Space>uL` | Toggle relative line numbers |
| `<Space>uw` | Toggle line wrap |
| `<Space>uh` | Toggle inlay hints |

### LSP

| Shortcut | Action |
|----------|--------|
| `gd` | Go to definition |
| `gD` | Show references |
| `gt` | Go to type definition |
| `gi` | Go to implementation |
| `grn` | Rename symbol |
| `gra` | Code action |
| `gO` | Document symbol |
| `K` | Hover documentation |

### Telescope (Find)

| Shortcut | Action |
|----------|--------|
| `<Space>ff` | Find files |
| `<Space>fw` | Live grep (root dir) |
| `<Space>fb` | Open buffers |
| `<Space>ft` | Treesitter symbols |
| `<Space>fR` | Recent files |
| `<Space>fC` | Colorscheme preview |
| `<Space>fn` | Nix search (manix) |
| `<Space>fM` | Man pages |
| `<Space>fm` | Jump to mark |
| `<Space>fh` | Help pages |
| `<Space>fk` | Keymaps |
| `<Space>fc` | Commands |
| `<Space>fd` | Workspace diagnostics |
| `<Space>fo` | Vim options |
| `<Space>:` | Command history |
| `<C-p>` (n/i) | Registers |

#### LSP Telescope

| Shortcut | Action |
|----------|--------|
| `<Space>flr` | References |
| `<Space>fli` | Incoming calls |
| `<Space>flo` | Outgoing calls |
| `<Space>fld` | Document symbols |
| `<Space>flw` | Workspace symbols |
| `<Space>fls` | Dynamic workspace symbols |
| `<Space>flm` | Implementation |
| `<Space>fle` | Definition |
| `<Space>flt` | Type definition |

#### Git Telescope

| Shortcut | Action |
|----------|--------|
| `<Space>fgc` | Git commits |
| `<Space>fgr` | Buffer commits range |
| `<Space>fgb` | Git branches |
| `<Space>fgs` | Git status |
| `<Space>fgt` | Git stash |

### Git (Gitsigns)

| Shortcut | Action |
|----------|--------|
| `<Space>gh` | Hunk operations prefix |
| `<Space>ghb` | Blame line |
| `<Space>ghd` | Diff this |
| `<Space>ghp` | Preview hunk |
| `<Space>ghR` | Reset buffer |
| `<Space>ghr` | Reset hunk |
| `<Space>ghs` | Stage hunk |
| `<Space>ghS` | Stage buffer |
| `<Space>ghu` | Undo stage hunk |

### Git (Neogit / Octo)

| Shortcut | Action |
|----------|--------|
| `<Space>gg` | Open Neogit |
| `<Space>goi` | Octo issue list |
| `<Space>gop` | Octo PR list |
| `<Space>goc` | Octo PR changes |
| `<Space>gor` | Octo review |

### Diagnostics (Trouble)

| Shortcut | Action |
|----------|--------|
| `<Space>x` | Diagnostics/quickfix prefix |
| `<Space>xx` | Document diagnostics |
| `<Space>xX` | Workspace diagnostics |
| `<Space>xt` | TODO list |
| `<Space>xq` | Quickfix list |

### File Browsers

| Shortcut | Action |
|----------|--------|
| `<Space>o` | Open Oil (file browser) |
| `<Space>e` | Open Yazi file manager |

Oil keymaps: `<CR>` select, `<C-\>` vsplit, `<C-enter>` split, `<C-t>` tab, `<C-p>` preview, `<C-c>` close, `<C-r>` refresh, `-` parent, `_` open cwd, `` ` `` cd, `~` tcd, `gs` sort, `gx` external, `g.` toggle hidden, `q` close, `g?` help.

### Terminal (ToggleTerm)

| Shortcut | Action |
|----------|--------|
| `<C-\>` (n/t) | Toggle terminal |
| `<Space>tt` | Send current line to terminal |
| `<Space>tv` (visual) | Send visual lines to terminal |
| `<Space>tV` (visual) | Send visual selection to terminal |
| `<esc><esc>` (terminal) | Escape to normal mode |

### Flash (Navigation)

| Shortcut | Action |
|----------|--------|
| `s` (n/x/o) | Flash jump (label-based navigation) |
| `R` (x/o) | Treesitter search |

### Debug (DAP)

| Shortcut | Action |
|----------|--------|
| `<Space>dc` | Continue |
| `<Space>dO` | Step over |
| `<Space>di` | Step into |
| `<Space>do` | Step out |
| `<Space>dp` | Pause |
| `<Space>db` | Toggle breakpoint |
| `<Space>dB` | Conditional breakpoint |
| `<Space>dR` | Toggle REPL |
| `<Space>dr` | Run last |
| `<Space>ds` | Session info |
| `<Space>dt` | Terminate |
| `<Space>dw` | Hover widget |
| `<Space>du` | Toggle DAP UI |
| `<Space>de` | Eval expression |

### Undotree

| Shortcut | Action |
|----------|--------|
| `<Space>ut` | Toggle undotree |
