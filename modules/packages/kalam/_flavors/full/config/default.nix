# kalam-full — the base flavor plus a LaTeX writing environment.
#
# Everything in base (blink.cmp / mini / snacks / catppuccin / nixd +
# pyright / gitsigns / the whole git surface / …) is pulled in verbatim
# via `../../base/config`; the `./latex` subtree layers the TeX toolkit
# on top. kalam-full therefore tracks any change to base automatically —
# there is no duplicated config here.
#
# LaTeX stack (modelled on ejmastnak's vim-latex guide):
#   - VimTeX          compilation (latexmk) + PDF viewer sync
#   - LuaSnip         autotriggered, math-zone-aware snippets
#   - texlab + ltex   language server + grammar/style checking
#   - conform         latexindent formatting
#
# See `../README.md` for the file map and `docs/kalam/full.md` for the
# feature walkthrough.
{
  imports = [
    ../../base/config
    ./latex
  ];
}
