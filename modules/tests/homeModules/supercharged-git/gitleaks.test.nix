# Tests for flake.homeModules.supercharged-git-gitleaks
# (neusis.supercharged-git.tools.gitleaks), through the umbrella.
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
            { neusis.supercharged-git.tools.gitleaks = { enable = true; } // extra; }
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
      tests.hm-supercharged-git-gitleaks = {
        test-installs-gitleaks = {
          expr = {
            on = t.hasPkg "gitleaks" home.home.packages;
            off = t.hasPkg "gitleaks" off.home.packages;
          };
          expected = {
            on = true;
            off = false;
          };
        };
      };
    };
}
