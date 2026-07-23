# Extend base's conform.nvim with a TeX formatter. `latexindent` ships
# inside the scheme-medium package put on PATH by vimtex.nix, so no
# extra `extraPackages` entry is needed here.
#
# latexindent is registered for on-demand use only — `<leader>cf`
# formats the buffer (async, untimed). Format-on-*save* is deliberately
# disabled for tex in opts.nix (`vim.b.disable_autoformat = true`),
# because latexindent's Perl startup exceeds conform's 500ms save budget
# and would time out on nearly every write. latexindent is conservative:
# it fixes indentation/alignment without reflowing your prose.
{
  plugins.conform-nvim.settings.formatters_by_ft.tex = [ "latexindent" ];
}
