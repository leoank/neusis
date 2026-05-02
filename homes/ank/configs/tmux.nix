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

      set -gu default-command
      set -g default-shell "$SHELL"
      set -gq allow-passthrough on
      set -sg terminal-overrides ",*:RGB"

      # popups
      bind-key T run "#{@popup-toggle} -Ed'#{pane_current_path}' -w75% -h75% --name=scratch"
      bind-key G run "#{@popup-toggle} -Ed'#{pane_current_path}' -w75% -h90% --name=lazygit lazygit"

    '';
  };
}
