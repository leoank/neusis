# Tests for flake.homeModules.terminal-velocity-mosh
# (neusis.terminal-velocity.tools.mosh), through the umbrella import.
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
            { neusis.terminal-velocity.tools.mosh = { enable = true; } // extra; }
          ];
        };

      home = withTool { };
      off = t.evalHm {
        pkgs = testPkgs;
        modules = [ self.homeModules.terminal-velocity ];
      };
    in
    {
      tests.hm-terminal-velocity-mosh = {
        test-installs-mosh = {
          expr = {
            on = t.hasPkg "mosh" home.home.packages;
            off = t.hasPkg "mosh" off.home.packages;
          };
          expected = {
            on = true;
            off = false;
          };
        };
      };
    };
}
