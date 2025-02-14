{ config, lib, pkgs, ... }:

{
  programs.zsh = {
    enable = true;
    #autocd = true;
    #enableAutosuggestions = true;
    enableCompletion = true;
    initExtraFirst = ".p10k.zsh";
    plugins = [
      {
        name = "zsh-powerlevel10k";
        src = "${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/";
        file = "powerlevel10k.zsh-theme";
      }
    ];
    shellAliases = {
      #ll = "ls -al";
      ".." = "cd ..";
      l = lib.mkForce "eza --all --icons=auto --classify=auto";
      ll = lib.mkForce "eza --long --all --git --header --icons=auto --classify=auto";
      t = "eza --oneline --all --icons=auto --classify=auto";
      tt = "eza --tree --all --classify=auto --icons=auto --level=2";
      ttt = "eza --tree --all --classify=auto --icons=auto --level=3";
      tttt = "eza --tree --all --classify=auto --icons=auto --level=4";
    };
  };
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };
}
