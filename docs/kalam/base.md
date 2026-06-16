# kalam (base) — what you actually get

A walkthrough of the `kalam` base flavor: what each option, autocmd,
and plugin does for you compared to a stock `nvim` install. Read
top-to-bottom on day one, or skim the table-of-contents and jump.

The full plugin list and file layout lives in
[`base/README.md`](../../new_modules/packages/kalam/_flavors/base/README.md).

---

## 0. The pitch

Stock `nvim` is a competent modal editor with no UI affordances,
no completion, no language servers wired up, no file picker, no
git integration, no terminal toggle, no startup screen, and a
status line that just shows `-- INSERT --`. kalam base gives you
all of that without:

- A vimscript config to maintain.
- 40+ plugin sources to pin.
- The Lazy/Packer load-order dance.
- Per-machine `:checkhealth` triage on update day.

Everything is declarative through nixvim. Three toolkits do the
bulk of the work:

| Toolkit       | Owns                                                                 |
| ------------- | -------------------------------------------------------------------- |
| `blink.cmp`   | Completion (LSP, snippets, path, buffer)                             |
| `mini.nvim`   | Code-editing QoL (surround, pairs, comments, text objects, …)        |
| `snacks.nvim` | UI / sessions (picker, terminal, dashboard, zen, notifier, indent, …) |

Plus the bare essentials: catppuccin (theme), treesitter +
context, LSP (`nixd` for Nix, `pyright` for Python),
format-on-save via `conform.nvim` (`nixfmt` and `ruff`),
gitsigns, lualine, bufferline, which-key.

---

## 1. Options (`opts.nix`)

Every setting below diverges from a vanilla nvim default. The
`why` column says what stock nvim does and why ours is better.

### Lines & gutter

| Option                 | Value      | Why                                                                                           |
| ---------------------- | ---------- | --------------------------------------------------------------------------------------------- |
| `number`               | `true`     | Stock: off. Without it you can't tell `:25` from `:250`.                                      |
| `relativenumber`       | `true`     | Lets you `5j` / `12dd` without counting; eyeballing the gutter shows the count.               |
| `cursorline`           | `true`     | Stock: off. The current row gets a faint highlight — easier to find after a long jump.        |
| `scrolloff = 8`        |            | Stock: 0. Keeps 8 lines of context above/below the cursor — no more typing at the screen edge. |
| `signcolumn = "yes"`   |            | Stock: `auto`. Prevents the screen from jumping by 1ch every time gitsigns/LSP add a sign.    |
| `wrap = false`         |            | Stock: on. Long lines stay on one row — code-shaped files are easier to scan.                 |
| `linebreak = true`     |            | When you *do* enable wrap (`<leader>uw`), it breaks at word boundaries, not mid-word.         |
| `breakindent = true`   |            | Wrapped lines start at the same indent — preserves visual block structure.                    |

### Indent

| Option           | Value | Why                                                                       |
| ---------------- | ----- | ------------------------------------------------------------------------- |
| `expandtab`      | `true`| Stock: off. Tabs become spaces — matches most modern codebases.           |
| `shiftwidth`     | `2`   | `>>` / `<<` shift by 2; pair with `expandtab` for spaces-only indent.     |
| `softtabstop`    | `2`   | Backspace removes 2 spaces as if they were a single indent unit.          |
| `tabstop`        | `2`   | Existing `\t` chars render 2-wide (rare in our codebases).                |
| `smartindent`    | `true`| Stock: off. Auto-indent the next line after `{`, `if`, etc.               |

> Language flavors that need 4-space indent (Python, Rust) override
> `shiftwidth`/`softtabstop`/`tabstop` via filetype autocmds.

### Search & grep

| Option       | Value                | Why                                                          |
| ------------ | -------------------- | ------------------------------------------------------------ |
| `ignorecase` | `true`               | `/foo` matches `Foo` and `FOO` — almost always what you want. |
| `smartcase`  | `true`               | …but `/Foo` keeps case-sensitive. The smart compromise.       |
| `grepprg`    | `rg --vimgrep`       | `:grep` uses ripgrep — 50× faster than the default `grep -n`. |
| `grepformat` | `%f:%l:%c:%m`        | Parses ripgrep's column output into the quickfix list.        |

### Splits

| Option       | Value  | Why                                                                  |
| ------------ | ------ | -------------------------------------------------------------------- |
| `splitbelow` | `true` | `:sp` opens below the current window. Stock opens above — confusing. |
| `splitright` | `true` | `:vsp` opens to the right. Reads left-to-right.                      |

### Files & undo

| Option       | Value  | Why                                                                            |
| ------------ | ------ | ------------------------------------------------------------------------------ |
| `swapfile`   | `false`| No `.swp` litter. Crash recovery is rare; the cost-benefit isn't worth it.     |
| `backup`     | `false`| No `~`-suffixed backups. Use git.                                              |
| `undofile`   | `true` | Stock: off. Persistent undo — `u` works across nvim sessions. **Huge.**        |
| `confirm`    | `true` | `:q` on a modified buffer prompts instead of erroring with `E37`.              |

### UI

| Option         | Value           | Why                                                                                              |
| -------------- | --------------- | ------------------------------------------------------------------------------------------------ |
| `termguicolors`| `true`          | 24-bit colour. Without it catppuccin renders as the 16 ANSI colours your terminal happens to set.|
| `showmode`     | `false`         | `-- INSERT --` is hidden — lualine shows mode in the status bar instead.                         |
| `timeoutlen`   | `300`           | Stock: 1000. which-key popup appears ~700ms faster after you press `<leader>`.                   |
| `updatetime`   | `200`           | Stock: 4000. CursorHold fires faster (used by gitsigns blame, treesitter context).                |
| `mouse = "a"`  |                 | Mouse works in all modes — useful for tmux pane resize even if you don't click around.            |
| `pumheight = 12`|                | Caps completion popup at 12 rows. Stock: 0 (fills the screen).                                    |
| `virtualedit = "block"` |        | In `<C-v>` block mode the cursor can roam past line ends — block edits behave intuitively.        |

### Folds

```nix
foldmethod = "expr";
foldexpr   = "v:lua.vim.treesitter.foldexpr()";
foldlevelstart = 99;  # files open fully expanded
```

Stock uses `manual` folds (you fold by hand). We delegate to
treesitter: `zc` collapses the current syntactic node, `zM` folds
everything, `zR` unfolds. Try it on a Nix file: `zc` on `{ … }`
folds the attrset.

---

## 2. Autocmds (`autocmds.nix`)

### `kalam_yank` — visible yank

```
yy            → the line briefly flashes a highlight, then fades.
```

Stock nvim gives no feedback. The flash tells you the yank happened
and how much you copied. 150ms — long enough to notice, short
enough to ignore.

### `kalam_cursor` — restore cursor on reopen

```
$ nvim src/foo.rs    # jump around, edit, :q
$ nvim src/foo.rs    # cursor lands where you left it
```

Stock nvim drops you at line 1 every time. Commit-message
buffers are exempt (you almost always want to start typing from
the top of `COMMIT_EDITMSG`).

### `kalam_trim` — trim trailing whitespace on save

```
foo:␠␠␠       <- spaces before newline
:w
foo:          <- gone, cursor stays put
```

Quietly cleans up trailing whitespace before write. The
`winsaveview` / `winrestview` pair means the cursor and scroll
position don't jump. Binary files and `diff` filetypes are
skipped (trimming a diff would corrupt it).

---

## 3. Core keymaps (`keymaps.nix`)

Only two. Everything else lives with its plugin.

| Key            | Action                       |
| -------------- | ---------------------------- |
| `<leader>` then `<space>` | `:write` — save the current buffer. |
| `<esc>`        | Clears the search highlight from a prior `/pattern`, then behaves like normal `<esc>`. |

Why so few? Stock nvim's defaults are dense and intentional —
overriding them invents muscle memory you have to relearn on every
other machine. Plugin bindings are namespaced under `<leader>`,
which doesn't exist in stock anyway.

---

## 4. which-key — the discoverability spine

Press `<leader>` and hold. After 300ms a popup lists every
binding that starts with leader, grouped by prefix.

```
 SPC           which-key
                 buffer    │  b
                 code      │  c
                 find/file │  f
                 git       │  g
                 quit      │  q
                 search    │  s
                 …
```

Press `f` and the popup refines to find-prefixed bindings:
`ff files`, `fg git files`, `fb buffers`, etc. Every binding in
kalam has a `desc`; every group letter has a label declared in
`plugins/whichkey.nix`.

**Practical workflow**: you don't memorize keymaps. You press
`<leader>` and look. Within a week your hands remember the
sequences you use; within a month you read the popup only for
the ones you don't.

---

## 5. Treesitter

Syntax highlighting that actually understands your code (not
regex hacks), better indent for `o`/`O`, and incremental
selection.

### Smart highlighting

Stock nvim has regex highlighting that gets fooled by template
strings, embedded SQL, JSX, etc. Treesitter parses the AST:
the highlighted token *is* the variable/keyword/string the
compiler sees.

### Incremental selection

```
<C-Space>     → select current node (e.g. an identifier)
<C-Space>     → expand to parent (e.g. the function call)
<C-Space>     → expand again (e.g. the statement)
<BS>          → shrink one level back
```

Stock `viw`/`vap` are byte-based — they don't know about function
boundaries. Treesitter selection grows along the AST.

### Treesitter context

A sticky header pins the enclosing function/class/block to the
top of the window as you scroll, so you always know *where in
the file you are*. Max 3 lines tall; activates on files
≥ 20 lines.

### Folds

Folds follow syntactic structure (functions, classes, blocks).
`zc`/`zo`/`zM`/`zR` work; `zA` toggles recursively.

---

## 6. LSP (`lsp.nix`)

**Base ships two servers: `nixd` for Nix and `pyright` for
Python.** Everything else is delegated to flavors (`kalam-v2`
adds its full polyglot set, future flavors layer their own).
What you get for free:

- `plugins.lsp.enable = true` with inlay hints on.
- The neovim 0.11+ default keymaps (`gd`, `K`, `grn`, `gra`,
  `gri`, `grr`, `]d`/`[d`) re-stated only to attach `desc`
  strings so which-key shows them labelled. **Defaults are
  preserved on purpose** — your muscle memory transfers to any
  vanilla nvim.
- `fidget.nvim` — small floating box near the cursor that shows
  LSP progress ("rust-analyzer: indexing 1240/2500…") instead of
  silently spinning.

### `nixd` (Nix)

- `pkgs.<TAB>` / `lib.<TAB>` completion via `<nixpkgs>` from
  `NIX_PATH`.
- Module-options completion (`services.<TAB>`,
  `home-manager.users.<x>.programs.<TAB>`, etc.) is **set per
  project** via an `.nvim.lua` exrc, not in kalam's base. nixd's
  `options.*` keys have to point at a specific flake and host,
  which is project-specific by nature — baking it into base
  would mean every kalam install paid for one flake's paths.
- kalam enables nvim's `exrc` option, so any `.nvim.lua` /
  `.nvimrc` / `.exrc` in your cwd is sourced at startup
  (subject to nvim's per-user trust list — accept the prompt
  the first time you open the project).
- This repo ships its own `.nvim.lua` at the root that wires
  `nixd` up against `darwinConfigurations.rogue` and the flake's
  pinned `nixpkgs` input. Use it as a template for new projects;
  see [nixd's configuration docs](https://github.com/nix-community/nixd/blob/main/nixd/docs/configuration.md).

### `pyright` (Python)

- Type-checking + completion. Auto-detects `.venv`,
  `pyproject.toml`, and pyenv shims for the right interpreter.
- Inlay hints on by default — parameter names appear inline
  at call sites, inferred variable types appear at
  declarations. Toggle with `<leader>uh`.
- No linter wired up here — `ruff` covers that via
  `conform.nvim` (see §6a).

### Default LSP keymap reference

| Key           | What                                              |
| ------------- | ------------------------------------------------- |
| `K`           | Hover docs                                        |
| `gd`          | Go to definition                                  |
| `gD`          | Go to declaration                                 |
| `gi`          | Go to implementation                              |
| `gy`          | Go to type definition                             |
| `gr`          | List references (quickfix)                        |
| `]d` / `[d`   | Next / previous diagnostic                        |
| `<leader>ca`  | Code action                                       |
| `<leader>cd`  | Open diagnostic float for the current line        |
| `<leader>cr`  | Rename symbol (LSP-driven; updates all callers)   |
| `<leader>cf`  | Format buffer (or selection in visual mode)       |

---

## 6a. Formatting — `conform.nvim`

A small dispatcher that picks the right formatter for each
filetype and invokes it on save. LSP formatting (`textDocument/
formatting`) is the **fallback** when no conform formatter is
registered.

### What's wired up in base

| Filetype | Formatter chain                              |
| -------- | -------------------------------------------- |
| `nix`    | `nixfmt` (RFC-style)                         |
| `python` | `ruff_organize_imports` → `ruff_format`       |
| anything else | LSP `formatting` if the server supports it |

The chain order matters — Python files get their imports
re-grouped *before* the body is reformatted, so `ruff format`
doesn't fight the import-sort pass.

### When formatting happens

- **On save** — silently, with a 500 ms timeout. If `nixfmt` /
  `ruff` errors out, the save still goes through; the
  formatter's stderr surfaces in the message area.
- **On `<leader>cf`** — explicit format. Works on a visual
  selection too (formats just the selected range).

### Adding a language

```nix
# in a flavor's plugins/formatting.nix overlay
plugins.conform-nvim.settings.formatters_by_ft = {
  rust = [ "rustfmt" ];
  go   = [ "gofmt" "goimports" ];
};
extraPackages = with pkgs; [ rustfmt go-tools ];
```

The formatter binary must be on PATH (hence `extraPackages`).

---

## 7. Completion — blink.cmp

A single completion engine, fast (Rust-backed sorting), with
LSP + path + snippet + buffer sources enabled by default.

### Type-ahead behaviour

```
let req = ht|         <- cursor here; menu pops with `http_get`, `http_post`, …
<Tab>                  <- (preset `super-tab`) move to next entry
<S-Tab>                <- previous entry
<C-Space>              <- force-open menu / toggle docs panel
<C-y>                  <- accept selection
```

Outside an open menu, `<Tab>` falls back to its normal behaviour
(jump in a snippet if you're inside one, insert a tab otherwise).

The menu *does not* preselect — you have to actively pick. Stock
`<CR>` always inserts a newline; ours never accidentally accepts
a completion when you wanted a newline.

### Ghost text

The most likely completion previews inline in dim text:

```
let req = ht█tp_get(…)
          ^^ cursor
```

Press `<Tab>` to accept the preview, or just keep typing — it
disappears non-disruptively.

### Auto-bracket pairs

Accepting a function completion adds `()`:

```
let req = ht<C-y>      →   let req = http_get(|)
```

The cursor lands between the parens, ready to type the first arg.

### Signature help

Inside `(…)` after a function name, a small floating panel shows
the function signature with the current arg highlighted. No
keybind needed — it follows your cursor.

### Snippets

LuaSnip is the snippet engine; base doesn't ship any snippets.
When a flavor adds one (e.g. `kalam-v2` adds Lean snippets), it
appears in the same blink menu alongside LSP results.

---

## 8. mini.nvim — editing QoL

mini modules are mostly *invisible* until you hit their trigger
key. Memorize the triggers; the rest is muscle memory.

### Text objects — treesitter-textobjects + vim defaults

mini.ai is **not** enabled. It used to coexist with
treesitter-textobjects but the two raced on `af`/`ac`/`aa`
keymaps (winner depended on typing speed). Removed for a clean
single-source-of-truth — see §5 for the treesitter-textobjects
keymaps that now own code-aware text objects.

The full set you have:

| Object | What                                                | Source |
| ------ | --------------------------------------------------- | ------ |
| `iw` / `aw` | word                                           | vim default |
| `iW` / `aW` | WORD                                           | vim default |
| `is` / `as` | sentence                                       | vim default |
| `ip` / `ap` | paragraph                                      | vim default |
| `i(` / `a(`, `ib` / `ab` | parens                            | vim default |
| `i[` / `a[`                | brackets                          | vim default |
| `i{` / `a{`, `iB` / `aB`   | braces                            | vim default |
| `i<` / `a<`                | angle brackets                    | vim default |
| `i"` / `a"`, `i'` / `a'`, `` i` `` / `` a` `` | quotes        | vim default |
| `it` / `at`                | HTML/XML tag                      | vim default |
| `if` / `af`                | function (treesitter-aware)       | treesitter-textobjects |
| `ic` / `ac`                | class                             | treesitter-textobjects |
| `ia` / `aa`                | parameter / argument              | treesitter-textobjects |

Example — change the first argument of a call:

```
foo(bar, baz)
^^^   cursor on `bar`
cia   →  delete `bar`, enter insert mode (treesitter parameter)
```

Lost in the swap: mini.ai's `a?` (prompt-based custom object)
and `aq` (any-quote). Both replicable — `a?` with a few presses
of the specific bracket/quote you wanted; `aq` with `a"`, `a'`,
or `` a` `` individually.

### `mini.surround` — wrap/unwrap

Prefixed with `gs` (parallel to `gc` for comment, `gS` for
splitjoin). The default `s*` prefix was vacated for leap (see
§8a) — `gs` reads as "**g**oto **s**urround mode".

```
gsa<motion><char>     surround add
gsd<char>             surround delete
gsr<from><to>         surround replace
```

Example:

```
hello                 visual-select with viw
gsaw"                 → "hello"
gsd"                  → hello
gsr"'                 → 'hello'
gsr"<                 → <hello>
```

Faster than copying / re-typing the brackets manually.

### `mini.pairs`

When you type `(`, you get `(|)` — cursor between, closing paren
inserted. Smart enough not to double the closing paren when one
already exists. Works for `()`, `[]`, `{}`, `''`, `""`, ``` `` ```.

### `mini.comment`

| Key     | What                          |
| ------- | ----------------------------- |
| `gcc`   | Toggle current line comment.  |
| `gc<motion>` | Toggle motion (e.g. `gcap` = paragraph). |
| `gc` (visual) | Toggle selection.      |

Filetype-aware: comments a Lua file with `--`, a Nix file with
`#`, a JSX file with `{/* */}` *inside* JSX vs `//` *outside*
(via treesitter context).

### `mini.move`

```
Alt-j / Alt-k    move current line down/up (normal & visual)
Alt-h / Alt-l    move current line/block left/right (visual)
```

Indenting follows automatically. Use it instead of `dd p`.

### `mini.bracketed`

A pile of `]X` / `[X` motions across diagnostics, quickfix,
buffers, indents, conflicts, jumps, yanks, etc. Examples:

```
]b / [b    next / prev buffer
]q / [q    next / prev quickfix entry
]c / [c    next / prev conflict marker
]y / [y    next / prev yank in jump list
]i / [i    indent change (handy in YAML)
```

### `mini.splitjoin`

```
foo(a, b, c)    →  gS  →   foo(
                            a,
                            b,
                            c,
                          )
```

…and back the other way with `gS` again. Works on Lua tables,
Python lists, JSON, etc.

### `mini.hipatterns`

`TODO`, `FIXME`, `HACK`, `NOTE`, `BUG` get coloured backgrounds.
Hex colours (`#3b82f6`) get a swatch behind them.

### `mini.bufremove`

```
<leader>bd     close buffer without closing the window
<leader>bD     same but force (drops modifications)
```

Stock `:bd` closes the window too if it's the only one in a
split. `mini.bufremove` keeps the split open with the next buffer
in its place.

---

## 8a. leap.nvim — on-screen jumps

Type two characters of the word you want to jump to. leap
highlights every match on screen and labels each with a single
letter; press the letter to jump.

| Key  | Mode    | Action                                                                      |
| ---- | ------- | --------------------------------------------------------------------------- |
| `s`  | n, v, o | leap in the **current window** — bidirectional, before and after the cursor |
| `S`  | n, v, o | leap **across all windows** in the current tab — jump straight into splits   |

Example — cursor at start of line, you want to land on the
second `enable` further down the screen:

```
1  programs.zsh.enable = true;     <- cursor here
2  programs.git.enable = true;
3  ...
4  services.openssh.enable = true; <- target
```

Type `sen`. leap finds every `en` on screen and labels them
(`a`, `b`, `c`…). The one on line 4 gets some label, say `c`.
Type `c` — cursor jumps.

In operator-pending mode (after `d`/`c`/`y`), leap also works:
`dsen<label>` deletes from the cursor to that point.

### Why we rebound mini.surround to `gs*`

leap's natural key is `s` ("snap"/"seek"), but that's also
mini.surround's prefix. We moved surround to `gs*` (see §8 →
`mini.surround`) so the single-keystroke motion stays unmodified.
Cost: one extra `g` keystroke when adding/removing surrounds.
Gain: instant on-screen jumps without a leader key.

The vim defaults overridden by leap are `s` (substitute
character) and `S` (substitute line), both replicated by `cl`
and `cc` respectively — same keystroke count, almost nobody uses
the originals.

---

## 9. snacks.nvim — UI / session toolkit

The biggest single piece of the config. Each feature replaces a
plugin you'd otherwise install separately.

### `snacks.bigfile`

Open a 50 MB log file. Stock nvim freezes for ~3 seconds turning
on syntax. `snacks.bigfile` notices the size, disables expensive
features (treesitter, LSP, indent guides, mini.cursorword) for
just that buffer, and opens instantly. Notification tells you it
fired:

```
Big file detected, disabling features: treesitter, lsp, …
```

### `snacks.quickfile`

When you `nvim file.txt` from the shell, snacks defers plugin
loading until *after* the file is on screen. Result: nvim
launches with the file visible ~30 % faster than stock.

### `snacks.dashboard`

`nvim` with no args (or `<leader>fr` and friends launch into it)
shows a homepage:

```
   .-.__      \\ .-.  ___  __
   |_|  '--.-.-(    …  (ascii art)

  ┌─ Keys ──────────────────────────────┐
  │ f Find File             <leader>ff  │
  │ r Recent Files          <leader>fr  │
  │ p Projects              <leader>sp  │
  │ q Quit                  <leader>qq  │
  └─────────────────────────────────────┘

  ┌─ Recent ────────────────────────────┐
  │ src/foo.rs                          │
  │ Cargo.toml                          │
  └─────────────────────────────────────┘
```

Stock nvim shows the help-screen welcome (`:intro`) which dies as
soon as you type. Dashboard is interactive: arrow keys move
between entries, `<CR>` activates.

### `snacks.picker` — the fuzzy finder

Replaces telescope with a smaller, faster API.

| Binding         | Picker                                |
| --------------- | ------------------------------------- |
| `<leader>ff`    | Files                                 |
| `<leader>fb`    | Open buffers                          |
| `<leader>fg`    | Git-tracked files                     |
| `<leader>fr`    | Recent files                          |
| `<leader>fh`    | Help tags                             |
| `<leader>fk`    | Keymaps (huge — fuzzy-search nvim's own help!) |
| `<leader>fc`    | Commands                              |
| `<leader>/`     | Live grep across the project          |
| `<leader>sw`    | Grep the word under cursor            |
| `<leader>sd`    | Diagnostics                           |
| `<leader>ss`    | LSP symbols in the buffer             |
| `<leader>sS`    | LSP symbols in the workspace          |
| `<leader>sm`    | Marks                                 |
| `<leader>sj`    | Jump list                             |
| `<leader>sq`    | Quickfix list                         |
| `<leader>su`    | Undo tree                             |
| `<leader>sr`    | Resume the last picker (with the state you left it in) |

Each picker has a live preview pane on the right (file contents,
git diff for commits, etc.).

### `snacks.terminal`

```
<leader>tt        toggle a floating terminal
```

Press `<leader>tt` once — a floating terminal opens. Press it
again — terminal hides but stays alive. Press again — it
reappears with the same scrollback and running processes. Stock
nvim makes you `:term` and manage the buffer yourself.

### `snacks.notifier`

Replaces `nvim-notify`. Diagnostics, LSP messages, and your own
`vim.notify(...)` calls render as small toast cards in the top
right that auto-dismiss after 3 seconds.

```
<leader>n         show notification history
```

### `snacks.indent` + `snacks.scope`

Indent guides as faint vertical bars. `scope` highlights the
guide for the block your cursor is in — easy to see which `if`
branch a line belongs to. No animation (intentionally — the
animation was distracting on fast typing).

### `snacks.input`

Replaces `vim.ui.input` with a centered floating window. Used by
LSP rename, telescope-style prompts, etc. Visually less jarring
than the cmdline.

### `snacks.statuscolumn`

Combines line numbers, fold indicators, gitsigns markers, and
diagnostic signs into one clean column. Stock nvim renders each
in a separate column, so the gutter pulses wider every time a
new sign appears.

### `snacks.toggle`

Smart UI toggles that store their last value and update which-key
descriptions live.

```
<leader>un  line numbers          (number)
<leader>ur  relative numbers      (relativenumber)
<leader>uw  wrap
<leader>us  spell
<leader>uh  inlay hints
<leader>ud  diagnostics
<leader>ui  indent guides
<leader>uD  dim (non-current windows)
<leader>uT  treesitter
```

Each one shows `[on]` / `[off]` in the which-key popup.

### `snacks.words`

Place your cursor on a word; the same word elsewhere on the
screen gets a subtle highlight. Updates as you move. Great for
spotting all the uses of a variable in a function.

### `snacks.zen` / `snacks.zen.zoom`

```
<leader>zz    distraction-free mode (centered window, no UI chrome)
<leader>zZ    zoom the current window to fill the screen
```

`zz` (zen) is good for writing prose; `zZ` (zoom) is good for
focusing on one window in a multi-split layout. Press the same
key to come back.

### `snacks.scratch`

```
<leader>.     open / toggle a scratch buffer for the current ft
<leader>S     pick a scratch buffer from the list
```

Per-filetype: opening `.` in a Lua buffer gives you a Lua
scratch, in Python a Python scratch, etc. Persisted across nvim
restarts.

### `snacks.lazygit` / `snacks.git`

```
<leader>gg    lazygit (floating, full repo)
<leader>gl    lazygit log (current branch)
<leader>gL    lazygit log for the current file only
<leader>gb    inline blame for the current line
<leader>gB    open the line on the git remote (GitHub/GitLab/sourcehut)
```

The lazygit popup is full-screen; press `q` to close (your
edits stay open in the background).

### `snacks.rename`

When you rename a file via LSP (`<leader>cR`), snacks updates all
the `import`/`require`/`use` statements that referenced the old
path across the project. Stock LSP rename only renames symbols
inside files — not file paths.

---

## 10. Git in the gutter — `gitsigns.nvim`

Repo-level git lives in `neogit` (status/commit/merge/push under
`<leader>g…`), side-by-side diffing in `diffview` (`<leader>gd…`),
and GitHub PRs/issues in `octo` (`<leader>go…`). The full
worked-example walkthrough is in [`git-workflow.md`](./git-workflow.md).
gitsigns handles *line-level* state: the signs in the gutter and
the operations on individual hunks.

### Gutter signs

```
▎    added line
▎    changed line
     deleted line above (small triangle)
     top deleted line of a block
▎    changedelete
▎    untracked
```

### Hunk operations

| Binding         | What                                             |
| --------------- | ------------------------------------------------ |
| `]h` / `[h`     | Next / prev hunk                                 |
| `<leader>ghs`   | Stage hunk (`v` mode = partial hunk)             |
| `<leader>ghr`   | Reset hunk (drop your change for that hunk)      |
| `<leader>ghS`   | Stage entire buffer                              |
| `<leader>ghR`   | Reset entire buffer                              |
| `<leader>ghu`   | Undo stage hunk (the inverse of `ghs`)           |
| `<leader>ghp`   | Preview hunk in a popup (shows the diff)         |
| `<leader>ghb`   | Blame the current line (full info, not just author) |
| `<leader>ghd`   | Open a vertical diffsplit vs HEAD                |

Practical workflow: stage selective hunks without leaving nvim —
no `git add -p` round trips.

### Inline blame

Off by default (it's busy on long files). Enable per-buffer:

```
:Gitsigns toggle_current_line_blame
```

After ~2 seconds idle on a line, the author/date/commit subject
appears in dim virtual text at the end of the line.

---

## 11. Status bar — `lualine`

A statusline that shows what stock nvim's `set ruler` can't:

```
 NORMAL   main +1~2   src/foo.rs   ●1 ⚠3   nix    25%   42:18
```

| Section        | What                                          |
| -------------- | --------------------------------------------- |
| `lualine_a`    | Mode (`NORMAL`, `INSERT`, `VISUAL`, …)        |
| `lualine_b`    | Git branch                                    |
| `lualine_c`    | Diagnostics counts + filename                 |
| `lualine_x`    | Git diff +/-/~ counts + filetype              |
| `lualine_y`    | Scroll progress (`25%`)                       |
| `lualine_z`    | Cursor position (`line:col`)                  |

`globalstatus = true` means one bar at the bottom of the screen,
not per-window — saves a row in multi-split layouts.

---

## 12. Tab bar — `bufferline`

Open buffers render as tabs at the top of the screen. Diagnostics
counts show next to the filename; modified buffers get a dot.

`<leader>bd` removes a buffer (mini.bufremove) and the tab
disappears. `<leader>ff` opens a file picker — picked file
becomes a new tab.

`always_show_bufferline = false` — the bar hides itself when only
one buffer is open. No wasted row.

---

## 12a. Navigating buffers, windows, and tabs

These are three distinct concepts that often get muddled. The
short version:

- **Buffer** — an open file (or a scratch area). Buffers live in
  memory regardless of whether they're visible. You can have 40
  buffers open while looking at only 1.
- **Window** — a viewport showing one buffer. Multiple windows
  can show different buffers (or the same buffer) side by side
  inside a single screen layout.
- **Tab** — a *collection of windows*. Each tab is its own
  workspace with its own split layout. Not like browser tabs;
  more like virtual desktops scoped to nvim.

### Buffers

Reach for these first — most of the day-to-day work is moving
between buffers, not creating splits or tabs.

| Binding         | What                                                                        |
| --------------- | --------------------------------------------------------------------------- |
| `<leader>,`     | snacks.picker.buffers — fuzzy pick from the buffer list, preview pane right |
| `<leader>fb`    | same picker (alias under the find/file group)                               |
| `]b` / `[b`     | next / previous buffer (mini.bracketed)                                     |
| `<C-^>`         | toggle between current and most-recent buffer (vim default)                 |
| `<leader>bd`    | delete current buffer **without closing the window** (mini.bufremove)       |
| `<leader>bD`    | same but force — drops unsaved modifications                                |
| `:b <name>`     | switch by name; `<TAB>` completes against open buffer names (vim default)   |
| `:bn` / `:bp`   | linear next / prev (vim default)                                            |

The bufferline at the top of the screen renders the open
buffers as tabs — visual reference, not navigation. The actual
ordering follows `<leader>,`'s fuzzy match or `]b`/`[b`'s
chronological list.

### Windows

`<leader>w` is a *proxy* for `<C-w>` (configured in
`whichkey.nix`). So `<leader>w` then `j` is the same as `<C-w>j`.
You can use either; the leader form gets the which-key popup with
labels, the `<C-w>` form is faster once memorized.

#### Creating / closing windows

| Keys              | What                                                                        |
| ----------------- | --------------------------------------------------------------------------- |
| `<C-w>s`          | split current window **horizontally** (new window below — `splitbelow` is on)   |
| `<C-w>v`          | split **vertically** (new window to the right — `splitright` is on)             |
| `<C-w>q` / `<C-w>c` | close current window (does NOT delete the buffer — use `<leader>bd` for that) |
| `<C-w>o`          | close every window *except* the current one ("only")                        |
| `<C-w>n`          | new window with an empty buffer                                             |

#### Moving between windows

| Keys                  | What                                  |
| --------------------- | ------------------------------------- |
| `<C-w>h/j/k/l`        | move focus left / down / up / right   |
| `<C-w>w`              | cycle to the next window              |
| `<C-w>p`              | jump to the *previous* window (works like `<C-^>` for buffers) |
| `<C-w>t`              | jump to the top-left window           |
| `<C-w>b`              | jump to the bottom-right window       |

#### Moving / resizing windows

| Keys                  | What                                                                                       |
| --------------------- | ------------------------------------------------------------------------------------------ |
| `<C-w>H/J/K/L`        | **move** the current window all the way to the left / down / up / right of the layout     |
| `<C-w>r` / `<C-w>R`   | rotate the windows clockwise / counter-clockwise                                           |
| `<C-w>=`              | equalize sizes — all windows get equal share of the screen                                 |
| `<C-w>_`              | maximize current window height                                                             |
| `<C-w>|`              | maximize current window width                                                              |
| `<C-w>+` / `<C-w>-`   | grow / shrink height by one row                                                            |
| `<C-w>>` / `<C-w><`   | grow / shrink width by one column                                                          |
| `<leader>zZ`          | snacks "zoom" — current window fills the screen until you press it again (no resize needed) |

### Tabs

Tabs in nvim aren't a 1-to-1 of editor tabs you might know from
vscode — they're more like *workspaces*. Each tab keeps its own
window layout, so you can have one tab with a 3-pane code/test/
file-tree setup, switch to another tab that's just one full-width
markdown buffer, and the layouts don't bleed.

Most kalam users don't reach for tabs often — bufferline + window
splits cover the common cases. But when you do, the bindings are
all stock vim defaults; we don't override them.

| Command / key    | What                                                                  |
| ---------------- | --------------------------------------------------------------------- |
| `:tabnew`        | open a new empty tab                                                  |
| `:tabnew <file>` | open `<file>` in a new tab                                            |
| `gt`             | next tab                                                              |
| `gT`             | previous tab                                                          |
| `<N>gt`          | jump to tab `<N>` (e.g. `3gt` → third tab)                            |
| `:tabclose`      | close current tab (all its windows go away; buffers stay open)        |
| `:tabonly`       | close every tab except the current one                                |
| `:tabmove +1`    | move current tab one position to the right                            |
| `:tabmove 0`     | move current tab to the very start                                    |
| `:tabnext` / `:tabprev` | long-form of `gt` / `gT`                                        |

If you live in tabs heavily, `:tab help foo` is a useful trick:
opens the help in a new tab instead of splitting your current
layout.

### Mental model — what gets destroyed when

This trips people up:

| Action                  | Buffer state                          | Window state                  | Tab state                       |
| ----------------------- | ------------------------------------- | ----------------------------- | ------------------------------- |
| `<C-w>q` / `<C-w>c`     | buffer **survives** in memory          | window closes                 | tab closes if last window       |
| `<leader>bd`            | buffer **deleted** from memory         | window stays — next buffer fills | unchanged                    |
| `:bd`                   | buffer deleted **and** any window showing it closes | windows close             | tab closes if last window       |
| `:tabclose`             | buffers in those windows survive       | all windows in that tab close | tab closes                       |
| `:qa`                   | all buffers gone                       | all windows gone              | all tabs gone (nvim exits)       |

The takeaway: `<leader>bd` is what you usually want — "I'm done
with this file, keep my layout". `<C-w>q` is the second most
common — "I'm done with this *view*, keep the file open".

---

## 13. A quick before/after

| Task                                       | Stock nvim                          | kalam base                                |
| ------------------------------------------ | ----------------------------------- | ----------------------------------------- |
| See what `<leader>` keys exist             | Read your config                    | Press `<leader>`                          |
| Open a file by name                        | `:e <path>`                         | `<leader>ff` + fuzzy type                 |
| Grep the project                           | `:grep` (manual)                    | `<leader>/` live, with preview            |
| Save and exit                              | `:wq`                               | `<leader><space>` save, `<leader>qq` quit |
| Comment a block                            | `:s/^/# /`                          | `gc` motion (or `V` then `gc`)            |
| Surround word with quotes                  | `i"<esc>ea"<esc>` (or yank+edit)    | `viwsa"`                                  |
| Jump to next diagnostic                    | `:lua vim.diagnostic.goto_next()`   | `]d`                                      |
| Stage a single hunk                        | `:!git add -p`                      | `<leader>ghs`                             |
| Open a terminal                            | `:term` (buffer takeover)           | `<leader>tt` (toggle, persistent)         |
| Highlight occurrences of word under cursor | `:set hlsearch` then `*`            | Nothing — it's already on (snacks.words)  |
| Find what you typed last week              | `:browse oldfiles`                  | `<leader>fr`                              |
| Zen mode for writing                       | install zen-mode.nvim               | `<leader>zz`                              |
| See git blame inline                       | install gitblame-nvim or run `:!git blame` | `<leader>ghb` (or `<leader>gb` for snacks's inline) |

---

## 14. When something feels wrong

- **Completion menu pops too aggressively / not enough?** Open
  `plugins/completion.nix`, tweak `completion.menu.auto_show`,
  `keymap.preset` (try `"super-tab"` or `"enter"`).
- **which-key popup too slow / too fast?** `opts.nix` →
  `timeoutlen` (lower = faster popup, but cuts your multi-key
  sequences shorter).
- **Indent guides distracting?** `<leader>ui` toggles them
  off for the session.
- **Diagnostic noise from a flaky LSP?** `<leader>ud` toggles
  diagnostics off. Or fix the LSP. (Probably fix the LSP.)
- **Picker preview pane too wide?** Open `plugins/snacks.nix`,
  add `picker.layout = "vertical"` to the settings block.
- **Want telescope back?** Add it to a flavor — base
  intentionally doesn't ship it. snacks.picker covers everything
  telescope does for most workflows.

---

## 15. Where to go next

- [`base/README.md`](../../new_modules/packages/kalam/_flavors/base/README.md)
  — file layout and module index.
- Extending base by layering language modules on top — see the
  "Extending" section of the README.
- [`flake.neusis.lib.kalam`](../../new_modules/lib/kalam.nix) —
  the helper namespace. `kalamLib.mkKeymap` and friends are
  available in every flavor config module via `extraSpecialArgs`.
