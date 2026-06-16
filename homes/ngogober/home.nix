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
      ".vim/vim_plugins.vim".source = ./vim/vim_plugins.vim;
      ".vim/common.vim".source = ./vim/common.vim;
      ".vim/base.vim".source = ./vim/base.vim;
    };
  };
}
