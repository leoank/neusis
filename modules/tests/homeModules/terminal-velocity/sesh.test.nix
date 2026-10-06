# Tests for flake.homeModules.terminal-velocity-sesh
# (neusis.terminal-velocity.tools.sesh), through the umbrella import.
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
            { neusis.terminal-velocity.tools.sesh = { enable = true; } // extra; }
          ];
        };

      home = withTool { };
      off = t.evalHm {
        pkgs = testPkgs;
        modules = [ self.homeModules.terminal-velocity ];
      };
    in
    {
      tests.hm-terminal-velocity-sesh = {
        test-enables-sesh-standalone-with-tmux-key = {
          expr = {
            on = home.programs.sesh.enable;
            pkg = lib.getName home.programs.sesh.package;
            key = home.programs.sesh.tmuxKey;
            # satisfies home-manager's tmux-integration assertion without tools.tmux
            fzfTmux = home.programs.fzf.tmux.enableShellIntegration;
            off = off.programs.sesh.enable;
            failed = t.failedAssertions home;
          };
          expected = {
            on = true;
            pkg = "sesh";
            key = "s";
            fzfTmux = true;
            off = false;
            failed = [ ];
          };
        };

        test-works-together-with-tmux = {
          expr =
            let
              cfg = t.evalHm {
                pkgs = testPkgs;
                modules = [
                  self.homeModules.terminal-velocity
                  { neusis.terminal-velocity.tools.tmux.enable = true; }
                  { neusis.terminal-velocity.tools.sesh.enable = true; }
                ];
              };
            in
            {
              both = cfg.programs.sesh.enable && cfg.programs.tmux.enable;
              failed = t.failedAssertions cfg;
            };
          expected = {
            both = true;
            failed = [ ];
          };
        };

        test-package-and-key-are-overridable = {
          expr =
            let
              cfg = withTool {
                package = testPkgs.hello;
                tmuxKey = "S";
              };
            in
            "${lib.getName cfg.programs.sesh.package}:${cfg.programs.sesh.tmuxKey}";
          expected = "hello:S";
        };
      };
    };
}
