# LaTeX domain index. One file per concern; `default.nix` (this file)
# only wires them together — mirrors base's `plugins/default.nix` style.
{
  imports = [
    ./opts.nix # buffer-local tex settings (conceal, spell, wrap)
    ./vimtex.nix # VimTeX + TeX Live + PDF viewer + which-key group
    ./treesitter.nix # hand tex highlighting to VimTeX (fixes in_mathzone)
    ./lsp.nix # texlab + ltex-ls
    ./luasnip.nix # autosnippets engine config + snippet loading
    ./formatting.nix # conform → latexindent
  ];
}
