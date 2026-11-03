# ADR-0016: kalam-zero is one nixvim-generated init.lua for Neovim 0.8+ with built-in fallbacks, plus an optional bundle of vendored plugins, released on a rolling GitHub release

Status: accepted
Date: 2026-11-03

## Context
kalam (the nixvim flavours under `modules/packages/kalam/`) needs Nix. On machines ank
reaches over ssh (servers, lab boxes, embedded boards) there is no Nix, often an old
Neovim, sometimes no git, no internet, and no writable home. The goal is to bring
the shortcuts and a few conveniences there with one download.

Alternatives considered:
- **A plugin manager on the target** (lazy.nvim bootstrap, or the built-in `vim.pack`):
  needs git and GitHub access on the machine and a writable data dir, and `vim.pack`
  needs Neovim 0.12. Plugin versions also drift from kalam's unless a lockfile is kept
  in sync. It fails exactly on the machines this is for.
- **No plugins ever:** maximally portable, but gives up the pickers and which-key even
  where Neovim is new enough to run them.
- **A plain-Vim vimrc as well:** more targets, but a second file to generate and test
  for a subset of shortcuts. Not now.
- **A hand-written Lua file:** works, but duplicates the shortcuts. EXP-20261103-g9kpxs
  (RUN-20261103-g9nmnp) showed nixvim can emit a portable file instead.

## Decision
- **A `zero` flavour** under `_flavors/zero`. It reuses base's `keymaps.nix` and adds
  its own options and autocmds, guarded by `vim.fn.has("nvim-0.x")` checks, plus a
  module of built-in fallbacks for the shortcuts base gets from plugins:
  - pickers become `:find`, `vim.ui.select` and `:grep` (`rg`, else `grep -rn`);
  - the explorers become netrw;
  - sessions become `:mksession` to `.nvim.session`, the file kalam's sessions use.
- **The generated `init.lua`** uses `wrapRc = false`, `impureRtp = true`,
  `luaLoader.enable = null`, and no Python or Ruby provider. A build check fails if a
  `/nix/store` path appears.
- **Target: Neovim 0.8 or newer.** Anything missing on the running version is skipped
  without an error. OSC 52 copy over ssh needs 0.10.
- **Plugins are optional and vendored.** A tarball puts pure-Lua plugins under
  `pack/kalam/start/`, built by Nix from the sources kalam pins (mini.nvim modules,
  which-key). The same `init.lua` upgrades a shortcut to the plugin version when
  `pcall(require, …)` finds it. No treesitter parsers, LSP servers or formatters.
- **Install** with `NVIM_APPNAME=kalam` (`~/.config/kalam/`), so an existing
  `~/.config/nvim` is never touched. Neovim 0.8 uses `nvim -u <file>`.
- **Releases:** a workflow replaces the files of a rolling `kalam-zero` GitHub release
  on every push to `main` that touches kalam, so the download URL never changes.

## Consequences
- Roughly 35–40 of kalam's ~130 shortcuts work without plugins. DAP, Neogit, Octo,
  diffview and LaTeX have no zero equivalent.
- A shortcut added to base's `keymaps.nix` reaches zero automatically; one added in a
  plugin module needs a fallback in zero's module, or it stays kalam-only.
- Each supported Neovim version needs testing, using official release builds in CI,
  since nixpkgs carries only the current one.
- A rolling release isn't reproducible by URL. A machine that needs a fixed version
  keeps its copy.
