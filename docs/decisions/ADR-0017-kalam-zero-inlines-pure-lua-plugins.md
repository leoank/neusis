# ADR-0017: kalam-zero's single file may carry pure-Lua plugins inlined as package.preload entries, starting with oil.nvim

Status: accepted
Date: 2026-11-03

## Context
ADR-0016 kept the single `init.lua` plugin-free and left plugins to an optional tarball.
That left netrw as the explorer in the file, where kalam's `<leader>o` is oil.nvim, a
directory as an editable buffer. ank asked for oil, or something like it, in zero
without much extra work.

Alternatives considered:
- **Write an oil-like buffer in `zero.lua`.** Listing a directory is easy. Turning
  edits back into renames, moves and deletes safely is most of oil, and the risky part.
- **Leave oil to the bundle (phase 4).** Little work, but the curl-one-file install,
  the common case, keeps netrw.
- **Inline oil into the file.** oil 2.15 (kalam's pin) is 37 pure-Lua modules, about
  370 KB, with its own checks down to Neovim 0.8, and nothing to install.

## Decision
- `kalam-zero-init` puts each Lua module of a plugin into the file as
  `package.preload["<module>"] = function(...) <file> end`, ahead of the config, so
  `require` resolves it with nothing on disk. The plugin's licence goes in as a comment
  above it.
- A plugin's `syntax/*.vim` files can't run through `vim.cmd` (`:finish`), so the file
  writes them into a per-process temp dir (`tempname()`) on 'runtimepath'.
- The plugin is the same derivation base uses (`kalam.config.plugins.oil.package`), so
  the pin can't drift. The wrapped `kalam-zero` loads it the normal way.
- `zero.lua` uses oil when `require("oil")` works (`<leader>o`, `<leader>e` as a float,
  `-` for the parent directory), and netrw otherwise.
- Only pure-Lua plugins qualify: no compiled parts, no external programs, no `plugin/`
  runtime files that must be sourced.

## Consequences
- The file grows from ~25 KB to ~380 KB, still one curl.
- Inlining another plugin is one line in `kalam.nix` plus its setup in `zero.lua`. Size
  and startup time are the budget, so each addition should earn its place.
- The tarball of ADR-0016 (phase 4) matters less. It stays the place for plugins too
  large to inline, or ones that need runtime files.
- Every Neovim version the file supports must also run the inlined plugins, so the
  phase 3 tests cover oil.
