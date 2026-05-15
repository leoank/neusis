{ pkgs, ... }:
{
  programs.sesh = {
    package = pkgs.unstable.sesh;
    enable = true;
    tmuxKey = "s";
  };
  programs.fzf.tmux.enableShellIntegration = true;
  programs.tmux = {
    enable = true;
    shell = "${pkgs.zsh}/bin/zsh";
    terminal = "tmux-256color";
    mouse = true;
    #sensibleOnTop = true;
    prefix = "C-b";
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
}
