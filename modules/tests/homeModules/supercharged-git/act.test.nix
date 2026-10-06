# Tests for flake.homeModules.supercharged-git-act
# (neusis.supercharged-git.tools.act), through the umbrella.
{ self, ... }:
{
  perSystem =
    { lib, testPkgs, ... }:
    let
      t = self.neusis.lib.tests;
      f = t.fixtures;

      withTool =
        extra:
        t.evalHm {
          pkgs = testPkgs;
          modules = [
            self.homeModules.supercharged-git
            f.gitIdentity
            { neusis.supercharged-git.tools.act = { enable = true; } // extra; }
          ];
        };

      home = withTool { };
      off = t.evalHm {
        pkgs = testPkgs;
        modules = [
          self.homeModules.supercharged-git
          f.gitIdentity
        ];
      };
    in
    {
      tests.hm-supercharged-git-act = {
        test-installs-act = {
          expr = {
            on = t.hasPkg "act" home.home.packages;
            off = t.hasPkg "act" off.home.packages;
            failed = t.failedAssertions home;
          };
          expected = {
            on = true;
            off = false;
            failed = [ ];
          };
        };
      };
    };
}
