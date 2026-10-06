# Tests for flake.homeModules.terminal-velocity-sesh
# (neusis.terminal-velocity.tools.sesh), through the umbrella import.
#
# home-manager's sesh module asserts `programs.fzf.tmux.enableShellIntegration`
# for its tmux integration; only `tools.tmux` sets that, so sesh is tested
# together with tmux and the standalone failure is pinned below.
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
            { neusis.terminal-velocity.tools.tmux.enable = true; }
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
        test-enables-sesh-with-tmux-key = {
          expr = {
            on = home.programs.sesh.enable;
            pkg = lib.getName home.programs.sesh.package;
            key = home.programs.sesh.tmuxKey;
            off = off.programs.sesh.enable;
            failed = t.failedAssertions home;
          };
          expected = {
            on = true;
            pkg = "sesh";
            key = "s";
            off = false;
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

        # KNOWN COUPLING, pinned: sesh without tools.tmux does not evaluate.
        # Fix candidates: have sesh.nix set
        # `programs.fzf.tmux.enableShellIntegration = true` itself, or
        # expose `enableTmuxIntegration` and default it off.
        test-sesh-alone-fails-home-manager-assertion = {
          expr =
            (t.evalHm {
              pkgs = testPkgs;
              modules = [
                self.homeModules.terminal-velocity
                { neusis.terminal-velocity.tools.sesh.enable = true; }
              ];
            }).programs.sesh.tmuxKey;
          expectedError = {
            type = "ThrownError";
            msg = "enable `programs.fzf.tmux.enableShellIntegration`";
          };
        };
      };
    };
}
