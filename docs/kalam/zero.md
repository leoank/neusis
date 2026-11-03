# kalam-zero: kalam on machines without Nix

kalam-zero is one `init.lua` you download and drop into a config folder. It carries
kalam's shortcuts and a few conveniences to machines that don't have Nix: servers you
ssh into, lab boxes, embedded boards. It needs Neovim 0.8 or newer and nothing else:
no git, no plugin manager, no internet after the download.

The design and its limits are in ADR-0016, ADR-0017 and ADR-0018
(`docs/decisions/`). The source is
[`modules/packages/kalam/_flavors/zero/`](../../modules/packages/kalam/_flavors/zero/README.md).

---

## 1. Install

```sh
curl -fsSL https://github.com/leoank/neusis/releases/download/kalam-zero/init.lua \
  --create-dirs -o ~/.config/kalam/init.lua
NVIM_APPNAME=kalam nvim
```

`NVIM_APPNAME=kalam` keeps it in `~/.config/kalam/`, next to the machine's own
`~/.config/nvim` (which it never touches). To make it your `nvim` on that machine, add
an alias to the shell's rc file:

```sh
alias vi='NVIM_APPNAME=kalam nvim'
```

**Neovim 0.8** predates `NVIM_APPNAME`. Pass the file instead:
`nvim -u ~/.config/kalam/init.lua`.

**No `curl`:** `wget -O ~/.config/kalam/init.lua <url>` after `mkdir -p ~/.config/kalam`.
busybox's `wget` often can't do https; use the next section.

**No internet on the target:** send the file over the ssh connection you already have.
Run this from your own machine:

```sh
curl -fsSL https://github.com/leoank/neusis/releases/download/kalam-zero/init.lua \
  | ssh host 'mkdir -p ~/.config/kalam && cat > ~/.config/kalam/init.lua'
```

From a neusis checkout, the same file is `nix build .#kalam-zero-init` (in
`result/init.lua`).

**No writable home:** any readable path works with `-u`, for example
`nvim -u /tmp/kalam.lua`. Undo history and sessions turn themselves off when the state
folder can't be written.

**Check the download:** each release also has `init.lua.sha256`:

```sh
curl -fsSL https://github.com/leoank/neusis/releases/download/kalam-zero/init.lua.sha256
sha256sum ~/.config/kalam/init.lua
```

**Update:** run the install command again. **Remove:**
`rm -rf ~/.config/kalam ~/.local/state/kalam ~/.local/share/kalam`.

**Try it locally first:** `nix run .#kalam-zero` from a neusis checkout runs the same
config.

---

## 2. What you get, by Neovim version

The release is rebuilt on every change to kalam on `main`, after the same headless test
passes on Neovim 0.8.3, 0.9.5, 0.10.4, 0.11.7 and 0.12.

| | 0.8 / 0.9 | 0.10+ |
|---|---|---|
| kalam's options and plain shortcuts (save, clipboard, esc) | yes | yes |
| oil.nvim on `<leader>o`, `<leader>e`, `-` | yes | yes |
| pickers (files, buffers, recent, help, grep) | built-in: `:find`, a numbered list, `:grep` into quickfix | mini.pick |
| hints for the next key (which-key's job) | none; `<leader>fk` lists every shortcut | mini.clue |
| surround (`gsa`/`gsd`/`gsr`), autopairs, move lines (Alt+hjkl), `]b`/`[q`…, `gS` | no | mini |
| copy over ssh (OSC 52) | yes | yes |
| fuzzy `:find` completion | no | 0.11+ (file list from rg, else git, else a glob) |

Nothing errors on an older Neovim: a feature it lacks is simply not set up.

---

## 3. Shortcuts

The keys are kalam's. `<leader>` is space.

| Keys | What |
|---|---|
| `<leader><space>` | save |
| `<leader>y` / `Y`, `<leader>p` / `P` | yank / paste with the system clipboard (OSC 52 over ssh) |
| `<leader>ff`, `<leader>fg` | find a file, find a git-tracked file |
| `<leader>fb`, `<leader>,` | buffers |
| `<leader>fr`, `<leader>fh`, `<leader>fc`, `<leader>:` | recent files, help, commands, command history |
| `<leader>fk` | every shortcut with its description |
| `<leader>/`, `<leader>sg`, `<leader>sw` | grep (rg if installed, else grep), grep the word under the cursor |
| `<leader>sr` | resume the last picker (0.10+) |
| `<leader>sd`, `<leader>sq`, `<leader>sm`, `<leader>sj` | diagnostics, quickfix, marks, jumps |
| `<leader>o`, `-`, `<leader>e` | oil here, oil on the parent, oil in a float |
| `<leader>bd` / `bD` / `bo` / `ba`, `<S-h>` / `<S-l>` | delete buffer / force / others / all, previous / next buffer |
| `<leader>qs` / `ql` / `qd`, `<leader>qq` / `qQ` | save / load / delete the session, quit all / force |
| `[d` / `]d`, `<leader>cd` | previous / next diagnostic, the line's diagnostics |
| `<leader>cf`, `<leader>cR` | format (LSP if attached, else `=`), rename the file |
| `<leader>xx` / `xX` / `xL` / `xQ` | diagnostics in quickfix / location list, open location list / quickfix |
| `gd` `gD` `gy` `gr` `K`, `<leader>ca` `cr` `ss` `sS` | LSP, when a server is attached |
| `<leader>gb`, `<leader>ghd`, `<leader>gdd` | git blame for the line, diff against the index, close the diff (with git) |
| `<leader>tt` | toggle a terminal split (`<C-\><C-t>` from inside it) |
| `<leader>w…` | window commands (`<C-w>`) |
| `<leader>un` / `ur` / `uw` / `us` / `ud` / `uu` | toggle numbers / relative / wrap / spell / diagnostics, undo tree (0.12) |
| `<leader>S`, `<leader>n` | scratch buffer, message history |

**Sessions** use `.nvim.session` in the current folder, the same file kalam's sessions
use. Loading is manual (`<leader>ql`): a session file is Vimscript, and on a machine you
ssh into the folder may be someone else's. A loaded session is saved again on exit. To
have a bare `nvim` load the folder's session, set `vim.g.kalam_zero_session_autoload =
true` in your own Lua (§6); even then it only loads a session you own that zero
saved, whose first line is `" kalam-zero session`.

---

## 4. Different from kalam

- No LSP servers, formatters or treesitter parsers are installed. LSP shortcuts appear
  only when a server attaches, and folds use indentation.
- No DAP, Neogit, diffview, Octo, leap or LaTeX. `<leader>gdd` closes the diff here,
  where kalam toggles diffview.
- `exrc` is off: on 0.8 it would run a project's `.nvim.lua` without asking, and a
  machine you ssh into may hold someone else's.
- No Nerd Font icons, and colours stay in the terminal's palette unless it advertises
  truecolor (`COLORTERM=truecolor`).
- `timeoutlen` is 800 ms, since there are no hints for multi-key shortcuts on 0.8/0.9.

---

## 5. Troubleshooting

- **`<leader>y` doesn't reach my clipboard.** OSC 52 needs a terminal that accepts it
  (most do). Inside tmux, set `set -g set-clipboard on`. zero only uses OSC 52 when
  the machine has no clipboard tool (xclip, wl-copy, pbcopy…).
- **`<leader>p` doesn't paste what I copied on my own machine.** OSC 52 carries copies
  out to your terminal, but few terminals answer requests to paste back in. Over OSC 52,
  `<leader>p` pastes Neovim's own last yank; to paste from your local clipboard, use the
  terminal's paste (Cmd-V, Ctrl-Shift-V) in insert mode.
- **A copy says it is too large for OSC 52.** Terminals drop payloads past about 100 KB,
  so zero keeps copies over ~73 KB in Neovim's registers instead of sending a part.
- **Grep finds nothing.** Without rg it runs `grep -rnH --exclude-dir=.git` from the
  current folder; start `nvim` at the project root.
- **Something looks wrong.** `<leader>n` shows the messages. `:lua print(vim.inspect(KalamZero.mini))`
  shows which mini modules loaded.

---

## 6. Your own Lua

Every `lua/*.lua` file next to `init.lua` runs after zero's config, in name order:
`~/.config/kalam/lua/` for the usual install, or the `lua/` folder beside the file you
pass to `-u`. It can change any option or shortcut zero sets, or add your own:

```lua
-- ~/.config/kalam/lua/10-local.lua
vim.g.kalam_zero_session_autoload = true      -- load this folder's session at startup
vim.o.relativenumber = false
vim.keymap.set("n", "<leader>m", "<cmd>make<cr>", { desc = "make" })
```

Modules go in a subfolder and load with `require`: `lua/mytools/init.lua` is
`require("mytools")`, also when the file was started with `-u`. A file that errors is
reported at startup (`<leader>n` shows it again), and the others still run. The release
never touches `lua/`, so updating `init.lua` keeps your files.

