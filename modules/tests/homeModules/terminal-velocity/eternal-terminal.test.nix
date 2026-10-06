# Tests for flake.homeModules.terminal-velocity-eternal-terminal
# (neusis.terminal-velocity.tools.eternal-terminal), through the umbrella import.
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
            { neusis.terminal-velocity.tools.eternal-terminal = { enable = true; } // extra; }
          ];
        };

      home = withTool { };
      off = t.evalHm {
        pkgs = testPkgs;
        modules = [ self.homeModules.terminal-velocity ];
      };
    in
    {
      tests.hm-terminal-velocity-eternal-terminal = {
        test-installs-et = {
          expr = {
            on = t.hasPkg "eternal-terminal" home.home.packages;
            off = t.hasPkg "eternal-terminal" off.home.packages;
          };
          expected = {
            on = true;
            off = false;
          };
        };
      };
    };
}
