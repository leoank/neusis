# Tests for flake.homeModules.terminal-velocity-tmux
# (neusis.terminal-velocity.tools.tmux), through the umbrella import.
{ self, ... }:
{
  perSystem =
    { lib, testPkgs, ... }:
    let
      t = self.neusis.lib.tests;

      withTool =
        extra:
        t.evalHm {
          pkgs = testPkgs;
          modules = [
            self.homeModules.terminal-velocity
            { neusis.terminal-velocity.tools.tmux = { enable = true; } // extra; }
          ];
        };

      home = withTool { };
      off = t.evalHm {
        pkgs = testPkgs;
        modules = [ self.homeModules.terminal-velocity ];
      };
    in
    {
      tests.hm-terminal-velocity-tmux = {
        test-enables-tmux-with-neusis-defaults = {
          expr = {
            on = home.programs.tmux.enable;
            prefix = home.programs.tmux.prefix;
            terminal = home.programs.tmux.terminal;
            mouse = home.programs.tmux.mouse;
            zshShell = lib.hasSuffix "/bin/zsh" home.programs.tmux.shell;
            plugins = lib.all (
              n: lib.any (p: lib.hasInfix n (lib.getName (p.plugin or p))) home.programs.tmux.plugins
            ) [ "vim-tmux-navigator" "resurrect" "continuum" "better-mouse-mode" "toggle-popup" ];
            seshBinding = lib.hasInfix "sesh last" home.programs.tmux.extraConfig;
            fzfTmux = home.programs.fzf.tmux.enableShellIntegration;
            off = off.programs.tmux.enable;
            failed = t.failedAssertions home;
          };
          expected = {
            on = true;
            prefix = "C-b";
            terminal = "tmux-256color";
            mouse = true;
            zshShell = true;
            plugins = true;
            seshBinding = true;
            fzfTmux = true;
            off = false;
            failed = [ ];
          };
        };

        test-prefix-shell-and-mouse-are-overridable = {
          expr =
            let
              cfg = withTool {
                prefix = "C-a";
                shellPath = "/bin/bash";
                mouse = false;
              };
            in
            {
              inherit (cfg.programs.tmux) prefix shell mouse;
            };
          expected = {
            prefix = "C-a";
            shell = "/bin/bash";
            mouse = false;
          };
        };
      };
    };
}
