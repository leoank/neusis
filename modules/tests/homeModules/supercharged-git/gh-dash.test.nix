# Tests for flake.homeModules.supercharged-git-gh-dash
# (neusis.supercharged-git.tools.gh-dash), through the umbrella.
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
            { neusis.supercharged-git.tools.gh-dash = { enable = true; } // extra; }
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
      tests.hm-supercharged-git-gh-dash = {
        test-installs-gh-dash = {
          expr = {
            on = t.hasPkg "gh-dash" home.home.packages;
            off = t.hasPkg "gh-dash" off.home.packages;
          };
          expected = {
            on = true;
            off = false;
          };
        };
      };
    };
}
