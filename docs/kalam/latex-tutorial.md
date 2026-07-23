# Writing LaTeX in kalam-full — a tutorial

A sit-down-and-do-it introduction to the LaTeX layer in `kalam-full`.
Work through it top to bottom with a scratch document open and you'll
be writing real math faster than you can in any WYSIWYG editor by the
end. For the *reference* (every snippet, every option), see
[`full.md`](./full.md).

> **Prerequisite:** you have `kalam-full` installed (it provides the
> `nvim` you're launching) and you know the base editor basics — if
> `<leader>ff` and `<leader>/` mean nothing to you, skim
> [`base.md`](./base.md) first.

> **Want a finished document to poke at instead?** Grab
> [`latex-playground.tex`](./latex-playground.tex) — a compilable
> article that exercises every feature below, with inline `TRY:`
> exercises. Copy it out and open it:
>
> ```bash
> mkdir -p /tmp/kalam-latex && cp latex-playground.tex /tmp/kalam-latex/
> cd /tmp/kalam-latex && nvim latex-playground.tex   # then ,ll to compile
> ```

The convention below: **`,`** is the local-leader, **`<space>`** is the
leader. So `,ll` means "comma, l, l"; `<leader>ff` means "space, f, f".

---

## 0. Install a PDF viewer (one time)

VimTeX previews with a real PDF app. Install the one for your platform:

- **macOS — [Skim](https://skim-app.sourceforge.io/).** `brew install
  --cask skim`. (Preview.app can't do SyncTeX; you need Skim.)
- **Linux — Zathura.** It's pulled in by your system config; if not,
  add `zathura` with SyncTeX support. `xdotool` is bundled by
  kalam-full already.

That's the only non-editor install. TeX Live itself is baked into
`kalam-full`.

---

## 1. Your first document

Make a file and open it:

```bash
mkdir /tmp/latex-demo && cd /tmp/latex-demo
nvim main.tex
```

Type this (or paste it — but typing teaches your fingers):

```latex
\documentclass{article}
\begin{document}
Hello, \LaTeX.
\end{document}
```

Now **start continuous compilation**:

```
,ll
```

You'll see a notification that the compiler started. VimTeX now
rebuilds every time you save. Save (`<leader><space>`), then **open the
PDF**:

```
,lv
```

Skim/Zathura opens showing your one-line document. Leave it open —
arrange it beside your terminal. From now on: edit, save, and the PDF
refreshes on its own.

> The aux files go into a `.build/` subdirectory, not your source
> folder. `ls` and you'll see `main.tex` and `.build/` — tidy.

---

## 2. Math at the speed of thought

This is the payoff. Put your cursor on a blank line in the document
body and type — literally type these characters:

```
mk
```

The instant you finish `mk`, it becomes `$ $` with your cursor in the
middle. **You're now in a math zone**, which unlocks the math snippets.
Type:

```
x=//
```

`//` becomes `\frac{ }{ }` with the cursor in the numerator. Type `a`,
press `<Tab>` to jump to the denominator, type `b`, `<Tab>` to jump
out. You just wrote `$x=\frac{a}{b}$` with 8 keystrokes and never
touched a backslash.

Keep going inside math — type each **exactly** as shown (mind the
spaces):

| You type  | You get      |
| --------- | ------------ |
| `xsr`     | `x^2` |
| `xtd`     | `x^{}` — cursor in the braces; type `n`, `<Tab>` out → `x^{n}` |
| `a__i`    | `a_{i}` |
| `;a`      | `\alpha` (renders as α with conceal on) |
| `a <= b`  | `a \leq b` |
| `ooo`     | `\infty` |
| `sum`     | `\sum_{}^{}` |

> **Postfix snippets attach with no space.** `sr` `cb` `td` `__` and
> `//` fire directly after the preceding token: type `xsr`, *not*
> `x sr` — the latter leaves a literal space (`x ^2`). Relation and
> operator snippets are the opposite: type `<=`, `xx`, `->` with the
> spaces you want *around* them (`a <= b` → `a \leq b`).

Now leave math — press `<Esc>` or move past the `$`. Type `//` in the
prose. **Nothing happens** — it stays literal `//`, because the
fraction snippet is math-zone-only. That context awareness is what lets
the triggers be so short.

### Display math

On a fresh line, type `dm`. You get:

```latex
\[
    ⟨cursor⟩
\]
```

a centred display equation. Everything inside is a math zone, so all
the snippets above work here too.

### The same math snippets work in Markdown

Open a `.md` file and the math snippets come along for the ride. Type
`mk` in prose → `$ $`; inside it, `//`, `sr`, `;a`, `lr(` all fire just
like in tex. `dm` opens a `$$ … $$` block (Markdown's display-math
syntax), and the snippets work inside it too. In prose they stay
literal. The only difference: text-face snippets (`bf`, `ita`, …) are
off in Markdown — use `**bold**` / `_italic_` there.

---

## 3. Wrapping existing text (the visual workflow)

Say you typed `E = mc^2` as plain text and *then* realised it should be
math. Don't retype it:

1. Visually select it — `V` or `viw`-style motions.
2. Press **`<Tab>`** (this stashes the selection).
3. Type the wrapping trigger — **`mk`**.

The selection reappears wrapped: `$E = mc^2$`. The same works with
`//` (selection becomes the numerator), `lr(` (selection wrapped in
`\left( \right)`), and the text faces (`bf` → `\textbf{selection}`).

---

## 4. Environments without the boilerplate

Environment scaffolds trigger with a leading `:` at the start of a
line. Type:

```
:eq
```

and get a ready-to-fill numbered equation:

```latex
\begin{equation}
    ⟨cursor⟩
\end{equation}
```

Others: `:ali` (align, for multi-line derivations — use `==` inside to
drop an `&=` alignment point), `:item` and `:enum` (lists, cursor on
the first `\item`), `:fig` (figure with `\includegraphics`, caption,
and label all stubbed), `:tab` (table + tabular).

For **any** environment, `:beg` is the generic one: type the
environment name once and it mirrors to the matching `\end`:

```
:beg  →  \begin{⟨name⟩}
             ⟨body⟩
         \end{⟨name⟩}
```

Type `theorem` in the first slot and the `\end{theorem}` updates live.

### Restructuring existing environments (VimTeX)

Cursor inside an environment:

- `cse` — **change surrounding environment** (turn an `equation` into
  an `align*` without touching the body).
- `dse` — delete the surrounding environment, keep the body.
- `tsd` — toggle `\left\right` delimiter sizing on the delimiters
  under the cursor.

---

## 5. Wire up inverse search

Forward search (`,lv`, editor → PDF) already works. **Inverse search**
(click in the PDF → jump to that line in nvim) needs a one-time setup.

### macOS / Skim

1. Skim → **Preferences → Sync**.
2. Check **"Check for file changes"** and **"Reload automatically"**.
3. **PDF-TeX Sync support** → Preset: **Custom**.
   - Command: `nvim`
   - Arguments: `--headless -c "VimtexInverseSearch %line '%file'"`
4. In the PDF, **`Cmd+Shift+click`** a line — nvim jumps to the source.

> Terminal Neovim receives the jump through VimTeX's server; make sure
> you launched `nvim` (not a detached process) for the file.

### Linux / Zathura

Nothing to configure. **`Ctrl+click`** a line in the PDF and Zathura
tells nvim to jump there (this is why `xdotool` is bundled).

---

## 6. Prose: spelling & grammar

Spell-check is already on in `.tex` files (from base):

- `]s` / `[s` — jump to next / previous misspelling.
- `z=` — suggestions for the word under the cursor.
- `zg` — add the word to your dictionary (`zw` marks it wrong).

Grammar and style come from **ltex-ls**, which checks on save. A clunky
sentence gets an underline like any diagnostic:

- `<leader>cd` — show the full message.
- `<leader>ca` — code actions: **"Add to dictionary"**, **"Disable
  rule"**, "Hide false positive". Accept one and ltex remembers it.
- Too noisy while drafting? `<leader>ud` toggles all diagnostics off
  for the buffer; flip it back on for a final pass.

---

## 7. Formatting & references

### Format on demand

`latexindent` cleans up indentation and environment alignment — run it
with `<leader>cf` (it won't reflow your sentences, only the structure).
Format-*on-save* is off for tex on purpose: latexindent's slow Perl
start-up would time out on every write, so kalam-full only runs it when
you ask.

### Cross-references with texlab

Give something a label — `\label{eq:energy}` — then elsewhere type
`\ref{` and start typing `eq`. **texlab** offers `eq:energy` in the
completion menu (base's blink menu). Same for `\cite{` against your
`.bib` file. Rename a label with `<leader>cr` and every `\ref` to it
updates.

Jump around a big document with the **table of contents**: `,lt` opens
it; `<CR>` on an entry jumps there. Or `<leader>ss` for a symbol
picker.

---

## 8. Putting it together — a worked example

Start from the skeleton in §1, `,ll` running, and write a short section
with a displayed derivation. Type this literally (triggers in **bold**
expand as you go):

> `\section{Kinetic energy}` ⏎
> `The kinetic energy is `**`mk`**`E = ` **`//`** `1``<Tab>``2``<Tab>` ⏎
> ` m v`**`sr`**` .` ⏎ ⏎
> `We can also write it as a displayed equation:` ⏎
> **`dm`** ⏎
> `E ` **`==`** ` ` **`//`** `1``<Tab>``2``<Tab>` ` m v`**`sr`**

(Note `v`**`sr`** with no space between them — `sr` is postfix, so it
attaches straight to the `v` to give `v^2`.)

Which builds, keystroke by keystroke, into:

```latex
\section{Kinetic energy}
The kinetic energy is $E = \frac{1}{2} m v^2$.

We can also write it as a displayed equation:
\[
    E &= \frac{1}{2} m v^2
\]
```

Save. The PDF refreshes with a typeset section and equation. Notice
you wrote two fractions, a superscript, inline and display math, and a
section heading without typing a single backslash or `\begin`.

Now select `Kinetic energy` in the heading, `<Tab>`, `bf` — and it's
`\textbf{Kinetic energy}`. Click the equation in the PDF (§5 inverse
search) and you land on that exact line in the source.

---

## 9. Cheat sheet

### Compile & view (`,` = localleader)

| Key   | What                            |
| ----- | ------------------------------- |
| `,ll` | toggle continuous compilation   |
| `,lv` | forward search (PDF → cursor)   |
| `,lt` | table of contents               |
| `,le` | error list                      |
| `,lk` | stop compiler                   |
| `,lc` | clean aux files                 |

### Math snippets (in a math zone)

| Trigger | → | Trigger | → |
| ------- | - | ------- | - |
| `//`    | `\frac{}{}` | `sr` `cb` | `^2` `^3` |
| `td` `__` | `^{}` `_{}` | `sq` | `\sqrt{}` |
| `sum` `dint` | `\sum` `\int` | `lim` | `\lim` |
| `;a` `;p` `;G` | α π Γ | `<=` `>=` `!=` | ≤ ≥ ≠ |
| `->` `=>` | → ⟹ | `ooo` | ∞ |
| `xbarr` `xhatt` `xvecc` | x̄ x̂ x⃗ | `tt` | `\text{}` |
| `lr(` `lr[` `lr\|` | `\left…\right…` | `:mat` `:cas` | matrix / cases |

### Enter math / structure

| Trigger | → |
| ------- | - |
| `mk`    | `$ $` (inline) |
| `dm`    | `\[ \]` (display) |
| `:eq` `:ali` | equation / align |
| `:item` `:enum` | itemize / enumerate |
| `:fig` `:tab` | figure / table |
| `:beg`  | generic environment |

### Faces

| Trigger | → | (how) |
| ------- | - | ----- |
| `bf` `ita` `emp` | `\textbf` `\textit` `\emph` | menu |
| `mbb` `mcal` | `\mathbb` `\mathcal` | auto, math |

### Visual wrap

Select → `<Tab>` → wrapping trigger (`mk`, `//`, `lr(`, `bf`, …).

---

## 10. Troubleshooting

| Symptom | Fix |
| ------- | --- |
| Math snippet won't fire | You're not in a math zone. `:echo vimtex#syntax#in_mathzone()` → should be `1`. |
| `//` expanded in prose | It shouldn't — that means you're inside math. Check for a stray `$`. |
| Forward search does nothing | No build yet / no `.synctex.gz`. Run `,ll`, save, then `,lv`. |
| Inverse search does nothing | Viewer not wired up — redo §5. |
| PDF won't open | Viewer not installed (§0) or wrong platform default. |
| ltex too noisy | `<leader>ud` to mute diagnostics; `<leader>ca` to disable a rule. |
| Conceal makes editing confusing | `:set conceallevel=0` for the buffer. |
| A LaTeX package is "not found" | scheme-medium lacks it — see [full.md §5](./full.md#5-tex-live). |

---

## Where to go next

- [`full.md`](./full.md) — the complete feature reference.
- [ejmastnak's guide](https://www.ejmastnak.com/tutorials/vim-latex/) —
  the source material; deeper on snippet-writing technique.
- The snippet files themselves:
  `new_modules/packages/kalam/_flavors/full/config/latex/snippets/tex/`
  — copy a snippet, tweak the trigger, rebuild to make it yours.
