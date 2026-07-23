# kalam-full — the LaTeX writing flavor

`kalam-full` is the `kalam` **base** editor (see [`base.md`](./base.md)
for everything the base gives you — completion, LSP, pickers, git, the
whole `<leader>` map) **plus a LaTeX authoring environment** layered on
top. This document covers *only* the LaTeX layer; if a feature isn't
mentioned here, it comes from base and is documented there.

The LaTeX layer is modelled on
[Ejike Mastnak's *Vim + LaTeX* series](https://www.ejmastnak.com/tutorials/vim-latex/),
adapted to nixvim + LuaSnip + blink.cmp. The design goal, borrowed
wholesale from that guide, is **"write LaTeX at the speed of thought"**:
you should almost never type a backslash or a `\begin{…}` by hand.

For a hands-on, sit-down-and-do-it introduction, read the
[tutorial](./latex-tutorial.md); to just start poking, open the
[`latex-playground.tex`](./latex-playground.tex) sample (a compilable
document with inline `TRY:` exercises for every feature). This page is
the reference: *what* exists and *why*.

---

## 0. The four pieces

| Piece                | File                | Owns                                              |
| -------------------- | ------------------- | ------------------------------------------------- |
| **VimTeX**           | `latex/vimtex.nix`  | compilation, PDF viewer sync, motions, conceal    |
| **LuaSnip snippets** | `latex/snippets/`   | fast math/text/environment entry                  |
| **texlab + ltex**    | `latex/lsp.nix`     | completion, refs, symbols, grammar/style          |
| **latexindent**      | `latex/formatting.nix` | source formatting via base's conform           |

Plus `latex/opts.nix`, which sets prose-friendly buffer options
(concealment, spell-check, soft-wrap cursor motion) for `tex` files.

---

## 1. VimTeX — compile & preview

VimTeX is the backbone. It drives `latexmk`, keeps a background
compile running as you type, and synchronises a real PDF viewer with
your cursor position (SyncTeX).

### Compilation

VimTeX's default mappings live under **`<localleader>l`** (localleader
is `,`, from base — so the prefix you actually press is `,l`). The
which-key popup labels the whole group; press `,l` and look.

| Key            | What                                                        |
| -------------- | ----------------------------------------------------------- |
| `,ll`          | **Toggle continuous compilation.** Turn it on once; every save recompiles in the background. |
| `,lk`          | Stop the compiler                                           |
| `,lv`          | **Forward search** — jump the PDF viewer to the cursor's line |
| `,lt`          | Open the table of contents (`:VimtexTocOpen`)               |
| `,le`          | Open the error/quickfix list (`:VimtexErrors`)              |
| `,lc`          | Clean aux files                                             |
| `,li`          | VimTeX info for the current project                         |

Builds are **out-of-source**: aux files (`.aux`, `.fls`, `.synctex.gz`,
the PDF) land in a `.build/` directory next to your `.tex` file, not
strewn through your source tree. Configured in `vimtex.nix` via
`g:vimtex_compiler_latexmk = { aux_dir = ".build"; out_dir = ".build"; }`
with `-synctex=1` so forward/inverse search works.

The quickfix window is set **not** to steal focus on every warning
(`g:vimtex_quickfix_mode = 0`) — overfull-hbox spam won't yank your
cursor away. Open it deliberately with `,le` when you want it.

### PDF viewer & inverse search

The viewer is chosen at **build time** by platform (VimTeX launches a
native GUI app, so it can't be picked at runtime):

- **macOS → Skim.** `g:vimtex_view_method = 'skim'`, with
  `view_skim_sync` + `view_skim_activate` so forward search reloads and
  raises Skim.
- **Linux → Zathura.** `g:vimtex_view_method = 'zathura'`; `xdotool` is
  bundled so forward search can focus the window.

**Forward search** (editor → PDF) is `,lv`. **Inverse search** (PDF →
editor: click a spot in the PDF, jump to that source line) needs a
one-time viewer configuration — see the
[tutorial §5](./latex-tutorial.md#5-wire-up-inverse-search). Skim needs
a preference set in its GUI; Zathura works out of the box with
`Ctrl+click`.

### Concealment

With `conceallevel=2` (set per-buffer in `opts.nix`) VimTeX renders
markup as the symbol it produces: `\alpha` shows as α, `\frac{a}{b}` as
a stacked fraction, `^`/`_` as raised/lowered text, `\ldots` as …. The
line **under your cursor** is always shown raw (`concealcursor=""`) so
you can edit the real source. Toggle it per-buffer with `:set
conceallevel=0`.

### Motions & text objects (free from VimTeX)

These aren't configured by us — they're VimTeX defaults worth knowing:

| Key         | Motion / object                                   |
| ----------- | ------------------------------------------------- |
| `]]` `[[`   | next / previous section                           |
| `ie` `ae`   | inner / around **e**nvironment                    |
| `i$` `a$`   | inner / around inline math                        |
| `dse`       | **d**elete **s**urrounding **e**nvironment        |
| `cse`       | **c**hange **s**urrounding **e**nvironment        |
| `dsc` `csc` | delete / change surrounding command               |
| `tsd`       | toggle `\left\right` delimiter sizing             |
| `%`         | jump between matched `\begin`/`\end`, `$…$`, etc.  |

---

## 2. Snippets — the heart of fast LaTeX

Snippets are why LaTeX-in-vim is faster than a WYSIWYG editor once you
learn them. kalam-full uses **LuaSnip** (already base's snippet engine
behind blink.cmp) with two ejmastnak techniques enabled:

- **Autosnippets** (`enable_autosnippets = true`) — the snippet fires
  the instant you finish typing its trigger. No Tab, no menu. This is
  what makes `//` → `\frac{}{}` feel like a keystroke.
- **Visual placeholders** (`store_selection_keys = "<Tab>"`) — select
  text, press `<Tab>`, then type a wrapping trigger; the selection is
  dropped inside. `viw` a word, `<Tab>`, `mk` → the word wrapped in `$ $`.

### Context awareness — the killer feature

Short triggers like `//`, `sr`, `;a` would be catastrophic if they
fired in prose. They don't: they're gated to **math zones** using
VimTeX's syntax engine —

```lua
local function in_mathzone()
  return vim.fn["vimtex#syntax#in_mathzone"]() == 1
end
```

So `//` inside `$…$` becomes `\frac{}{}`, but `and/or` in a sentence
stays literal. Conversely `mk` (enter inline math) is gated to *text*
so it won't fire when you're already in math.

### Autosnippet vs. menu snippet

Two expansion styles, chosen per snippet by how dangerous the trigger
is in prose:

- **Autosnippet** — fires immediately. Used for math (safe, because
  math-zone-gated) and for `:`/`;`/`lr`-prefixed triggers (safe,
  because no English word starts that way).
- **Regular (menu) snippet** — surfaces as an item in blink's
  completion menu; you accept it to expand. Used for text faces
  (`bf`, `ita`, `emp`) whose triggers are too word-like to auto-fire.

### The snippet library

Organised by category under `snippets/tex/`, LuaSnip loads the whole
directory for the `tex` filetype.

#### `math.lua` — math mode

| Trigger  | Result                     | Zone   |
| -------- | -------------------------- | ------ |
| `mk`     | `$ ⟨cursor⟩ $` inline math | text   |
| `dm`     | `\[ … \]` display math     | line start |
| `//`     | `\frac{ }{ }`              | math   |
| `sr` `cb`| `^2` `^3`                  | math   |
| `td` `__`| `^{ }` `_{ }`              | math   |
| `sq`     | `\sqrt{ }`                 | math   |
| `ee`     | `e^{ }`                    | math   |
| `sum` `prod` | `\sum_{}^{}` `\prod_{}^{}` | math |
| `dint`   | `\int_{}^{} … \, d…`       | math   |
| `lim`    | `\lim_{n \to \infty}`      | math   |
| `ooo`    | `\infty`                   | math   |
| `!=` `<=` `>=` | `\neq` `\leq` `\geq` | math   |
| `~~` `~=`| `\sim` `\approx`           | math   |
| `==`     | `&=` (align point)         | math   |
| `xx` `**`| `\times` `\cdot`           | math   |
| `->` `!>` `=>` | `\to` `\mapsto` `\implies` | math |
| `iff` `fa` `tee` | `\iff` `\forall` `\exists` | math |
| `...`    | `\dots`                    | math   |
| `tt`     | `\text{ }`                 | math   |
| `xbar` `xhat` `xvec` | `\bar{x}` `\hat{x}` `\vec{x}` (postfix) | math |

#### `greek.lua` — Greek letters (`;` prefix, math only)

`;a`→α, `;b`→β, `;g`→γ, `;d`→δ, `;e`→ε, `;q`→θ, `;l`→λ, `;m`→μ, `;p`→π,
`;s`→σ, `;f`→φ, `;w`→ω … and the capitals with the capital letter:
`;G`→Γ, `;D`→Δ, `;L`→Λ, `;P`→Π, `;S`→Σ, `;W`→Ω. Variant forms:
`;ve`→ε (varepsilon), `;vf`→φ (varphi), `;vq`→ϑ (vartheta).

#### `environments.lua` — scaffolds (`:` prefix)

| Trigger | Environment                              |
| ------- | ---------------------------------------- |
| `:beg`  | generic — type the name, it mirrors to `\end` |
| `:eq`   | `equation`                               |
| `:ali`  | `align`                                  |
| `:item` | `itemize` + first `\item`                |
| `:enum` | `enumerate` + first `\item`              |
| `:fig`  | `figure` + `\includegraphics` + caption + label |
| `:tab`  | `table` + `tabular` + caption + label    |
| `:mat`  | `pmatrix` (in math)                      |
| `:cas`  | `cases` (in math)                        |

Block environments require the trigger at the **start of a line**;
`:mat`/`:cas` fire inside math.

#### `delimiters.lua` — auto-sized delimiters (`lr` prefix, math only)

`lr(`→`\left( \right)`, `lr[`→`\left[ \right]`,
`lr{`→`\left\{ \right\}`, `lr|`→`\left| \right|`,
`lra`→`\left\langle \right\rangle`. The closing delimiter is always
emitted, so pairs can't get unbalanced.

#### `fonts.lua` — faces

Text faces surface in the completion menu (type + accept): `bf`→`\textbf`,
`ita`→`\textit`, `emp`→`\emph`, `mono`→`\texttt`, `tsc`→`\textsc`.
Math faces autosnippet inside math: `mbb`→`\mathbb`, `mcal`→`\mathcal`,
`mbf`→`\mathbf`, `mrm`→`\mathrm`, `mfr`→`\mathfrak`.

### Editing / reloading snippets

The snippet files are baked into the nix store (read-only). To iterate
on them, edit the files under
`new_modules/packages/kalam/_flavors/full/config/latex/snippets/tex/`
and rebuild the flavor. There's no live-reload in the packaged build —
that's the trade-off for a fully declarative, reproducible editor.

---

## 3. Language servers

Layered onto base's `plugins.lsp` (which already gives you the 0.11
default keymaps `gd`, `K`, `gr`, `]d`/`[d`, and blink completion).

### texlab

- Completion for `\ref{…}`, `\cite{…}`, package names, and command
  names — all flowing through base's blink.cmp menu.
- Document symbols (`<leader>ss`), workspace symbols (`<leader>sS`),
  and rename that updates `\label`/`\ref` pairs together.
- Diagnostics parsed from the build log, plus `chktex` lint on
  open/save.
- **Build-on-save is deliberately off.** VimTeX owns compilation;
  letting texlab also drive `latexmk` would make two processes fight
  over the same `.build/` lock.

### ltex-ls

Grammar, spelling, and style checking for your **prose** — it runs
LanguageTool under the hood and understands LaTeX structure (it won't
flag your `\commands`, only your words). Checks on save
(`checkFrequency = "save"`) to stay quiet while you type.

- Diagnostics appear inline like any other; `<leader>cd` shows the
  float, `<leader>sd` lists them in the picker.
- "Add to dictionary" / "Disable rule" are offered as **code actions**
  (`<leader>ca`) — accept one and ltex remembers it.
- Noisy by nature. If it gets in the way, `<leader>ud` (base's
  diagnostics toggle) silences all diagnostics for the buffer.

---

## 4. Formatting

`latexindent` is registered with base's `conform.nvim` for the `tex`
filetype. It fixes indentation and environment alignment **without
reflowing your prose** (it won't rewrap sentences).

- **On save** — subject to base's format-on-save toggle. Off? flip it
  with `<leader>uf`.
- **On demand** — `<leader>cf` (works on a visual selection too).

The `latexindent` binary ships inside the `scheme-medium` TeX Live
package that `vimtex.nix` puts on `PATH`, so it's available to conform
and in the `:terminal` without a separate install.

---

## 5. TeX Live

kalam-full bundles `texlive.combined.scheme-medium` (~1.5 GB) — enough
for the overwhelming majority of documents (article/report/beamer, the
AMS math packages, graphics, biblatex, etc.). If a document needs a
package the medium scheme lacks, either:

1. bump the scheme to `scheme-full` in `latex/vimtex.nix`, or
2. add the specific `texlivePackages.<name>` to that file's `texlive`
   let-binding.

The same package is exposed on `PATH`, so `latexmk`, `pdflatex`,
`biber`, and `latexindent` all work from a `:terminal` inside the
editor too.

---

## 6. What base already gave you (quick pointers)

You don't need LaTeX-specific tooling for these — they come from base
and work in `.tex` files automatically:

- **Spell-check** is on for `tex` (`opts.nix`): `]s`/`[s` jump between
  misspellings, `z=` suggests, `zg` adds a word.
- **Soft-wrap motion**: `j`/`k` move by *screen* line in prose, so long
  paragraphs navigate naturally.
- **snacks.picker**: `<leader>ff` files, `<leader>/` live-grep,
  `<leader>ss` symbols (works via texlab in tex).
- **Git**: the full `<leader>g` surface (neogit / diffview / gitsigns).
- **Terminal**: `<leader>tt` for a compile-and-watch shell if you'd
  rather drive `latexmk` yourself.

---

## 7. When something feels wrong

- **A math snippet won't fire.** You're probably not in a math zone —
  check the concealment/highlight, or that `$…$` actually surrounds the
  cursor. `:echo vimtex#syntax#in_mathzone()` prints `1` in math.
- **`mk` fired inside a word.** It shouldn't (regex-guarded), but a
  start-of-line `mk` uses the `^mk` variant — report the surrounding
  text if it misbehaves.
- **Forward search does nothing.** Compilation must have produced a
  `.synctex.gz` (it's in `.build/`). Confirm a build ran (`,ll`), then
  `,lv`.
- **Inverse search does nothing.** One-time viewer setup —
  [tutorial §5](./latex-tutorial.md#5-wire-up-inverse-search).
- **ltex is too noisy.** `<leader>ud` toggles diagnostics; or narrow
  its rules via a code action.
- **Concealment is confusing while editing.** `:set conceallevel=0`
  for the buffer.
