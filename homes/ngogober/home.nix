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
      bat
      # pkgs for zsh cusotomizations
      zsh-powerlevel10k
      meslo-lgs-nf
    ];

    file = {
      ".vimrc".source = ./vim/.vimrc;
      ".vim/plugins.vim".source = ./vim/plugins.vim;
      ".vim/common.vim".source = ./vim/common.vim;
    };
  };
}
