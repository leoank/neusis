{ pkgs, ... }:
{
  enableMan = false;

  imports = [
    ./opts.nix
    ./keymaps.nix
    ./autocmds.nix
    ./plugins
  ];

  extraPackages = with pkgs; [
    fd
    fzf
    ripgrep
  ];
}
