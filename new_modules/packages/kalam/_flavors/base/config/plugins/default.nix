# Domain index. One file per logical concern, not per plugin —
# domains may pull in multiple plugins (e.g. ui = lualine +
# bufferline + web-devicons).
{
  imports = [
    ./theme.nix
    ./whichkey.nix
    ./treesitter.nix
    ./lsp.nix
    ./completion.nix
    ./formatting.nix
    ./mini.nix
    ./snacks.nix
    ./files.nix
    ./git.nix
    ./worktrees.nix
    ./leap.nix
    ./trouble.nix
    ./editor.nix
    ./dap.nix
    ./ui.nix
  ];
}
