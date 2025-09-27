{ config, lib, pkgs, ... }:

{
  programs.zsh = {
    enable = true;
    #autocd = true;
    #enableAutosuggestions = true;
    enableCompletion = true;
    initContent = lib.mkMerge [
      (lib.mkBefore "source $HOME/neusis/homes/ngogober/.p10k.zsh")
      (lib.mkAfter ''
        ZVM_INSERT_MODE_CURSOR=$ZVM_CURSOR_BLOCK
        # zsh-vi-mode overrides ^R, so we re-source
        zvm_after_init_commands+=('source <(fzf --zsh)')
      '')
    ];
    plugins = [
      {
        name = "zsh-powerlevel10k";
        src = "${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/";
        file = "powerlevel10k.zsh-theme";
      }
      {
        name = "zsh-nix-shell";
        file = "nix-shell.plugin.zsh";
        src = pkgs.fetchFromGitHub {
          owner = "chisui";
          repo = "zsh-nix-shell";
          rev = "v0.8.0";
          sha256 = "1lzrn0n4fxfcgg65v0qhnj7wnybybqzs4adz7xsrkgmcsr0ii8b7";
        };
      }
      {
        name = "vi-mode";
        src = pkgs.zsh-vi-mode;
        file = "share/zsh-vi-mode/zsh-vi-mode.plugin.zsh";
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
    oh-my-zsh.enable = lib.mkForce false;
  };
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };
}
