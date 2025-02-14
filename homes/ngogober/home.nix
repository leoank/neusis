{ pkgs, ... }:
{
  imports = [ ./zsh.nix ];
  home = {
    username = "ngogober";
    homeDirectory = "/home/ngogober";

    packages = with pkgs; [
      jq
      fzf
      #exa
      eza # better maintained than exa
      hexyl
      # pkgs for zsh cusotomizations
      zsh-powerlevel10k
      meslo-lgs-nf
    ];
  };
}
