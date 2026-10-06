# kalam (base)

The base kalam flavor — a minimal-but-complete nixvim distribution
that other flavors (`py`, `v2`, future per-domain ones) layer onto.

Built from three primary toolkits and nothing else for QoL:

- **[blink.cmp](https://github.com/saghen/blink.cmp)** — sole
  completion engine. LuaSnip enabled as the snippet backend; no
  snippets defined in base.
- **[mini.nvim](https://github.com/echasnovski/mini.nvim)** — owns
  every code-editing concern: surround, pairs, comments, text
  objects (`ai`), block move, bracketed motions, splitjoin,
  hipatterns, icons, bufremove.
- **[snacks.nvim](https://github.com/folke/snacks.nvim)** — owns
  every UI/session concern: dashboard, picker (replaces telescope),
  terminal (replaces toggleterm), notifier (replaces nvim-notify),
  indent guides (replaces indent-blankline), zen, scratch, statuscolumn,
  toggle, words, bigfile, quickfile, rename, input.

Plus the bare essentials:
- catppuccin (theme), treesitter + context, LSP (`nixd` +
  `pyright`), format-on-save via `conform.nvim` (`nixfmt` +
  `ruff`), gitsigns, lualine, bufferline, which-key.

## Layout

```
config/
├── default.nix          entry point
├── opts.nix             vim options
├── keymaps.nix          two non-plugin bindings: <leader>space=save, esc=noh
├── autocmds.nix         yank highlight, restore cursor, trim trailing ws
└── plugins/
    ├── theme.nix        catppuccin
    ├── whichkey.nix     group spec — every <leader>X label declared here
    ├── treesitter.nix
    ├── lsp.nix          nixd + pyright; flavors layer more
    ├── formatting.nix   conform.nvim → nixfmt / ruff (+ extras per flavor)
    ├── completion.nix   blink.cmp + LuaSnip
    ├── mini.nix         mini.* modules
    ├── snacks.nix       snacks.* modules + most of the leader keymaps
    ├── git.nix          gitsigns + hunk operations
    └── ui.nix           lualine, bufferline, web-devicons
```

## Keymap conventions

Every leader binding has a `desc` and a group declared in
`whichkey.nix` — `<leader>` on its own shows the whole map.

Bindings live next to their plugin. To find one, grep the leader
sequence (`grep -rn '<leader>fg' config/`).

Default neovim 0.11+ LSP keymaps (`gd`, `K`, `grn`, `gra`, `gri`,
`grr`, `]d`/`[d`) are preserved — `lsp.nix` re-declares them only
to attach `desc` strings so which-key shows them labelled. Don't
override defaults in flavor extensions unless necessary.

## Extending

To add a language to your flavor, layer one or two files on top
of base's imports:

```nix
# my-flavor/config/default.nix
{ pkgs, ... }: {
  imports = [
    ../../base/config        # everything in base
    ./plugins/lang/python.nix
  ];
}
```
