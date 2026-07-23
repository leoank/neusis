# VimTeX owns tex highlighting — and it must, for three features to work:
# concealment, the math/environment motions, and crucially
# `vimtex#syntax#in_mathzone()`, which every math autosnippet gates on.
#
# nvim-treesitter's `latex` highlighter conflicts head-on: when it is
# active, Vim's syntax engine never loads (`b:current_syntax` stays nil),
# so `synstack()` is empty and `in_mathzone()` returns 0 *everywhere* —
# silently disabling every math-zone snippet (`//`, `sr`, `;a`, `lr(`, …)
# and breaking conceal. It also fires VimTeX's "highlighting is
# controlled by Treesitter" warning on every tex buffer.
#
# Disabling *highlight* for `latex` hands tex rendering back to VimTeX.
# The treesitter parser still attaches, so folds/indent keep working.
{
  plugins.treesitter.settings.highlight.disable = [ "latex" ];
}
