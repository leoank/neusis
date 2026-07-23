# kalam-full

`kalam` base **plus a complete LaTeX writing environment**, packaged as
`kalam-full`.

Everything in [base](../base/README.md) is inherited verbatim — this
flavor's `config/default.nix` does nothing but

```nix
{
  imports = [
    ../../base/config   # all of base
    ./latex             # the LaTeX layer
  ];
}
```

so kalam-full always tracks base. The LaTeX layer is modelled on
[ejmastnak's *Vim + LaTeX* guide](https://www.ejmastnak.com/tutorials/vim-latex/):
VimTeX for compilation and PDF sync, LuaSnip autosnippets for
near-instant math entry, `texlab` + `ltex-ls` for language-server
features and grammar, and `latexindent` for formatting.

## What the LaTeX layer adds

| Concern            | Tool / mechanism                                                        |
| ------------------ | ----------------------------------------------------------------------- |
| Compilation        | **VimTeX** → `latexmk` (out-of-source `.build/` dir, SyncTeX on)         |
| PDF viewer         | **Skim** (macOS) / **Zathura** (Linux), forward + inverse search        |
| Snippets           | **LuaSnip** autosnippets, math-zone aware (`vimtex#syntax#in_mathzone`)  |
| Language server    | **texlab** (completion, symbols, refs) + **ltex-ls** (grammar/style)     |
| Formatting         | **latexindent** via base's `conform.nvim`                               |
| Concealment        | VimTeX conceal + `conceallevel=2` (per-buffer)                          |
| TeX distribution   | `texlive.combined.scheme-medium`                                         |

## Layout

```
config/
├── default.nix              imports ../../base/config + ./latex
└── latex/
    ├── default.nix          domain index
    ├── opts.nix             FileType tex: conceal, spell, wrap, no autoformat
    ├── vimtex.nix           VimTeX + TeX Live + viewer + which-key group
    ├── treesitter.nix       disable TS highlight for latex (VimTeX owns it)
    ├── lsp.nix              texlab + ltex-ls (layered onto base's lsp)
    ├── luasnip.nix          enable_autosnippets + load ./snippets
    ├── formatting.nix       conform: tex → latexindent (on-demand only)
    └── snippets/tex/        LuaSnip snippet library (filetype = tex)
        ├── math.lua         inline/display math, fractions, powers, relations
        ├── greek.lua        `;`-prefixed Greek letters
        ├── environments.lua `:`-prefixed environment scaffolds
        ├── delimiters.lua   `lr(`-style auto-sized \left \right pairs
        └── fonts.lua        text faces (menu) + math faces (auto)
```

## Snippet cheat-sheet

Autosnippets expand the instant you type the trigger. `mk` and `dm`
fire in text; everything under "math" fires only inside a math zone.

| Trigger | Expands to                | Where       |
| ------- | ------------------------- | ----------- |
| `mk`    | `$ ⟨cursor⟩ $`            | text        |
| `dm`    | `\[ … \]`                 | line start  |
| `//`    | `\frac{}{}`               | math        |
| `sr` `cb` | `^2` `^3`               | math        |
| `td` `__` | `^{}` `_{}`             | math        |
| `sum` `dint` `lim` | `\sum` `\int` `\lim` | math   |
| `;a` `;p` `;G` | `\alpha` `\pi` `\Gamma` | math     |
| `lr(` `lr[` `lr\|` | `\left( \right)` …   | math        |
| `:beg` `:eq` `:ali` | environment scaffolds | line start |
| `bf` `ita` `emp` | `\textbf{}` … (via menu) | tex only |
| `mbb` `mcal` | `\mathbb{}` `\mathcal{}` | math    |
| `xbarr` `xhatt` `xvecc` | `\bar{x}` `\hat{x}` `\vec{x}` | math (postfix) |

The visual workflow: select text, press `<Tab>`, type a wrapping
trigger (`mk`, `//`, `lr(`, `bf`, …) — the selection lands inside.

**Markdown too:** the math snippets also fire in `.md` files inside
`$…$` / `$$…$$` (math context detected via treesitter instead of
VimTeX). `dm` emits `$$ $$` there; text faces stay tex-only. Wired via
`filetype_extend("markdown", { "tex" })` in `latex/luasnip.nix`.

Full walkthrough: [`docs/kalam/full.md`](../../../../../docs/kalam/full.md)
(features) and
[`docs/kalam/latex-tutorial.md`](../../../../../docs/kalam/latex-tutorial.md)
(tutorial).

## Extending

Add a package the medium scheme lacks, or a new snippet file, by
layering more modules under `latex/` — the same pattern base documents.
To change the Linux viewer or TeX Live scheme, edit `latex/vimtex.nix`.
