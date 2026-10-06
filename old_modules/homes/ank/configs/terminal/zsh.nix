{ pkgs, ... }:
{
  programs.zsh = {
    enable = true;
    zprof.enable = false;
    plugins = [
      {
        name = "vi-mode";
        src = pkgs.zsh-vi-mode;
        file = "share/zsh-vi-mode/zsh-vi-mode.plugin.zsh";
      }
    ];
    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "gh"
        "globalias"
      ];
    };
    shellGlobalAliases = {
      G = "| grep --color=auto -i -n";
    };
    shellAliases = {
      oc = "opencode";
      ll = "eza -lah --color-scale=all --hyperlink";
      lt = "eza -l --git --git-repos --tree --level=2 --color-scale=all --hyperlink";
      n = "nvim";
      nvt = "nvim +terminal";
      ns = "nix search nixpkgs";
      cat = "bat";
      df = "duf";
    };

    #https://discourse.nixos.org/t/terminal-zsh-performance-issue-under-home-manager-help/55798/11
    completionInit = ''
      autoload -Uz compinit
      fpath=(''${(ou)fpath}) # Stable fpath order hence consistent cache hit.
      if [[ ! -s ''${ZDOTDIR:-$HOME}/.zcompdump || \
            /run/current-system/sw -nt ''${ZDOTDIR:-$HOME}/.zcompdump ]]; then
        compinit
        zcompile ''${ZDOTDIR:-$HOME}/.zcompdump 2>/dev/null
      else
        compinit -C
      fi
    '';
    initContent =
      let
        zshConfig = pkgs.lib.mkOrder 1000 ''
          function nz() {
            cd $(zoxide query $1) && nvim
          }
          function nx() {
            nix-shell -p $@
          }
          function nxp() {
            nix-shell -p "python3.withPackages(p: with p; [$@])"
          }
          function nxpc() {
            nix-shell --arg config "{ allowUnfree = true; cudaSupport = true; }" -p "python3.withPackages(p: with p; [$@])"
          }


          export EDITOR=nvim
          export TERM=xterm
          # Add env var for vi mode editor
          export ZVM_VI_EDITOR=$EDITOR
        '';
        zshLateInit = pkgs.lib.mkOrder 1500 ''
          # https://github.com/nix-community/home-manager/issues/7816
          # https://github.com/jeffreytse/zsh-vi-mode/issues/242
          # Workaround to make vi-mode work with atuin
          # Similarly fzf can also be enabled if required
          function zvm_after_init() {
            eval "$(fzf --zsh)"
            zvm_bindkey viins '^R' atuin-search
            zvm_bindkey vicmd '^R' atuin-search
            # Add keytimeout for surround to work
            # https://github.com/softmoth/zsh-vim-mode/issues/13?issue=zsh-users%7Czsh-autosuggestions%7C254
            export KEYTIMEOUT=30
          }
        '';
      in
      pkgs.lib.mkMerge [
        zshConfig
        zshLateInit
      ];

  };
}
