# terminal-velocity: tmux module.
# Enables `programs.tmux` with vim-tmux-navigator, resurrect +
# continuum (auto-save/restore sessions, even across reboots),
# better-mouse-mode, and tmux-toggle-popup. The bundled `extraConfig`
# sets up six popup bindings (scratch, yazi, lazygit, rmpc,
# agent-deck, ipython) — they assume those binaries exist on PATH if
# you actually hit the keys.
#
# When `supercharged-shell.tools.fzf` is also enabled, fzf's
# tmux shell integration is auto-wired (Ctrl-T inside tmux pops the
# fzf pane).
{ ... }:
{
  flake.homeModules.terminal-velocity-tmux =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.neusis.terminal-velocity.tools.tmux;
    in
    {
      options.neusis.terminal-velocity.tools.tmux = {
        enable = lib.mkEnableOption "tmux multiplexer";

        shellPath = lib.mkOption {
          type = lib.types.str;
          default = "${pkgs.zsh}/bin/zsh";
          defaultText = lib.literalExpression ''"''${pkgs.zsh}/bin/zsh"'';
          example = lib.literalExpression ''"''${pkgs.fish}/bin/fish"'';
          description = "Shell tmux invokes inside panes.";
        };

        prefix = lib.mkOption {
          type = lib.types.str;
          default = "C-b";
          example = "C-a";
          description = "tmux prefix key.";
        };

        terminal = lib.mkOption {
          type = lib.types.str;
          default = "tmux-256color";
          description = "Value of TERM inside tmux panes.";
        };

        mouse = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable mouse support.";
        };
      };

      config = lib.mkIf cfg.enable {
        programs.tmux = {
          enable = true;
          inherit (cfg)
            prefix
            terminal
            mouse
            ;
          shell = cfg.shellPath;

          plugins = with pkgs; [
            {
              plugin = tmuxPlugins.vim-tmux-navigator;
              extraConfig = ''
                setw -g mode-keys vi
                bind-key h select-pane -L
                bind-key j select-pane -D
                bind-key k select-pane -U
                bind-key l select-pane -R
                unbind -T root C-\\
                unbind -T prefix t
                unbind -T prefix r
                unbind -T copy-mode-vi C-\\
              '';
            }
            {
              plugin = tmuxPlugins.resurrect;
              extraConfig = ''
                set -g @resurrect-strategy-nvim 'session'
                set -g @resurrect-capture-pane-contents 'on'
              '';
            }
            {
              plugin = tmuxPlugins.continuum;
              extraConfig = ''
                set -g @continuum-restore 'on'
                set -g @continuum-boot 'on'
                set -g @continuum-save-interval '10'
                set -g @continuum-boot-options 'wezterm'
              '';
            }
            tmuxPlugins.better-mouse-mode
            tmuxPlugins.tmux-toggle-popup
          ];

          extraConfig = ''
            bind-key L run-shell "sesh last"
            bind-key R source-file "~/.config/tmux/tmux.conf"


            set -gu default-command
            set -g default-shell "$SHELL"
            set -g allow-passthrough on
            set -ga update-environment TERM
            set -ga update-environment TERM_PROGRAM
            set -sg terminal-overrides ",*:RGB"

            # popups
            set -gF @popup-id-format '#{b:pane_current_path}/{popup_name}'
            bind-key t run "#{@popup-toggle} -Ed'#{pane_current_path}' -w75% -h90% --name=scratch"
            bind-key y run "#{@popup-toggle} -Ed'#{pane_current_path}' -w75% -h90% --name=yazi yazi"
            bind-key g run "#{@popup-toggle} -Ed'#{pane_current_path}' -w75% -h90% --name=lazygit lazygit"
            bind-key m run "#{@popup-toggle} -Ed'#{pane_current_path}' -w75% -h90% --name=rmpc rmpc"
            bind-key a run "#{@popup-toggle} -Ed'#{pane_current_path}' -w75% -h90% --name=agent-deck agent-deck"
            bind-key p run "#{@popup-toggle} -Ed'#{pane_current_path}' -w75% -h90% --name=ipython ipython"

            if -F '#{TMUX_POPUP_SERVER}' {
              set -g copy-command "tmux -Ldefault loadb -w -"
              bind -T prefix ] run "tmux -Ldefault saveb - | tmux loadb -" \; pasteb -p
              bind -T copy-mode-vi y send -X copy-pipe-and-cancel
              bind -T copy-mode-vi MouseDragEnd1Pane send -X copy-pipe-and-cancel
            }
          '';
        };

        # fzf-tmux shell integration — no-op when fzf isn't enabled,
        # extra Ctrl-T binding inside tmux when it is.
        programs.fzf.tmux.enableShellIntegration = true;
      };
    };
}
