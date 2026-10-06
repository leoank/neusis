# ank's zsh hmBundle.
# Ported verbatim from `homes/ank/configs/terminal/zsh.nix` into a
# named bundle so it can be referenced from
# `flake.neusis.users.ank.neusisOS.machineToBundlesMap.<host>`.
#
# To use on a host, add this bundle to that host's entry:
#
#   flake.neusis.users.ank.neusisOS.machineToBundlesMap = {
#     <host> = [ self.neusis.users.ank.hmBundles.zsh ];
#   };
{ ... }:
{
  flake.neusis.users.ank.hmBundles.zsh =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      programs.zsh = {
        enable = true;
        zprof.enable = false;

        # XDG-respecting history location + cap at 10k entries.
        history = {
          path = "${config.xdg.dataHome}/zsh/history";
          size = 10000;
        };

        # Inline gray suggestion from history as you type — accept
        # with `→` (right arrow) or `Ctrl-F` (end-of-line). The
        # `history` strategy reads from $HISTFILE; `completion`
        # falls back to zsh's completer when history misses. Both
        # are stacked: history wins, completion fills the gap.
        # Per-keystroke cost is single-digit ms — startup unchanged.
        autosuggestion = {
          enable = true;
          strategy = [ "history" "completion" ];
        };

        # Colorize the command line as you type — unknown commands
        # in red, valid in green, options/strings highlighted, etc.
        # Real per-keystroke cost but imperceptible under ~1000
        # chars of input.
        syntaxHighlighting.enable = true;

        plugins = [
          {
            name = "vi-mode";
            src = pkgs.zsh-vi-mode;
            file = "share/zsh-vi-mode/zsh-vi-mode.plugin.zsh";
          }
        ];

        oh-my-zsh = {
          enable = true;
          # Skip the default `robbyrussell` theme — the PROMPT
          # below owns the prompt. Empty string short-circuits
          # the theme loader entirely.
          theme = "";
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

        # https://discourse.nixos.org/t/terminal-zsh-performance-issue-under-home-manager-help/55798/11
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
            zshConfig = lib.mkOrder 1000 ''
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

              # `update <host>` — rebuild a NixOS host from this flake.
              function update() {
                sudo nixos-rebuild switch --flake .#$1 -v
              }

              # `darwin <host>` — rebuild a nix-darwin host from this flake.
              function darwin() {
                sudo darwin-rebuild switch --flake .#$1 -v
              }


              export EDITOR=nvim
              export TERM=xterm
              # Add env var for vi mode editor
              export ZVM_VI_EDITOR=$EDITOR

              # ── Prompt ────────────────────────────────────────
              # Two-line, classic minimal:
              #
              #   ~/path/to/project  (main)
              #   ❯
              #
              # `%~` is the cwd (with $HOME → ~). `%(?...)` flips
              # the arrow's colour by the last command's exit
              # status. vcs_info supplies the `(branch)` segment —
              # built into zsh, no plugin needed; empty outside a
              # git repo. The arrow drops to its own line so long
              # paths and branch names don't push it off-screen.
              autoload -Uz vcs_info
              precmd_vcs_info() { vcs_info }
              precmd_functions+=( precmd_vcs_info )
              zstyle ':vcs_info:*' enable git
              zstyle ':vcs_info:git:*' formats ' %F{8}(%b)%f'
              setopt prompt_subst
              PROMPT='%F{blue}%~%f''${vcs_info_msg_0_}
              %(?.%F{green}.%F{red})❯%f '
            '';

            zshLateInit = lib.mkOrder 1500 ''
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
          lib.mkMerge [
            zshConfig
            zshLateInit
          ];
      };
    };
}
