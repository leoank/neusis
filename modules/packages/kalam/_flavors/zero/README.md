# kalam-zero

kalam for machines without Nix: one `init.lua` for Neovim 0.8+, no external tools
required (ADR-0016). Its plugins travel inside the file (ADR-0017): oil.nvim, and on
Neovim 0.10+ mini's surround, pairs, move, bracketed, splitjoin, pick and clue (ADR-0018).
About 900 KB, ~25 ms to load.

| Package | What it is |
|---|---|
| `kalam-zero` | this config wrapped by nixvim, for trying it locally (`nix run .#kalam-zero`) |
| `kalam-zero-init` | the same config as a standalone `$out/init.lua`, with the plugins inlined as `package.preload` entries; the build fails if it names the Nix store |

Files:

- `config/default.nix`: imports base's `opts.nix` and `keymaps.nix`, and overrides
  what doesn't suit a random machine: indent folds instead of treesitter, `exrc` off,
  truecolor only when the terminal advertises it, a longer `timeoutlen` (no which-key).
- `config/zero.lua`: built-in fallbacks for the shortcuts base gets from plugins, the same
  keys mapped to `:find`, `vim.ui.select`, `:grep` (rg, else grep), oil (netrw if oil
  can't load), `:mksession`
  (`.nvim.session`, the file kalam's sessions use), quickfix and diagnostics, LSP on
  attach, a git diff against the index. Plus OSC 52 copy when there is no clipboard
  tool, a Lua statusline, and `<leader>fk` to list every shortcut. Anything newer than
  0.8 is behind `has()`. On 0.10+ it also sets up the inlined mini modules with base's
  settings (surround on `gs…`), and the pickers and grep use mini.pick.

Tests: `modules/tests/packages/kalam/kalam-zero.test.nix`. The headless checks
(`checks.<system>.kalam-zero-headless{,-no-rg}`) install `init.lua` under
`NVIM_APPNAME=kalam` and run every fallback; on x86_64-linux the same test runs on the
official 0.8–0.11 release builds.
