# kalam-zero

kalam for machines without Nix: one `init.lua` for Neovim 0.8+, no external tools
required (ADR-0016). Its one plugin, oil.nvim, travels inside the file (ADR-0017).

| Package | What it is |
|---|---|
| `kalam-zero` | this config wrapped by nixvim, for trying it locally (`nix run .#kalam-zero`) |
| `kalam-zero-init` | the same config as a standalone `$out/init.lua`, with oil.nvim inlined as `package.preload` entries; the build fails if it names the Nix store |

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
  0.8 is behind `has()`.

Tests: `modules/tests/packages/kalam/kalam-zero.test.nix`. The headless checks
(`checks.<system>.kalam-zero-headless{,-no-rg}`) install `init.lua` under
`NVIM_APPNAME=kalam` and run every fallback.
