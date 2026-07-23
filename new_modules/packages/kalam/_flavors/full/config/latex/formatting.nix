# Extend base's conform.nvim with a TeX formatter. `latexindent` ships
# inside the scheme-medium package put on PATH by vimtex.nix, so no
# extra `extraPackages` entry is needed here.
#
# Format-on-save is the base default (gated behind the `<leader>uf`
# toggle); `<leader>cf` formats on demand. latexindent is conservative —
# it fixes indentation/alignment without reflowing your prose.
{
  plugins.conform-nvim.settings.formatters_by_ft.tex = [ "latexindent" ];
}
