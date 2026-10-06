# Tests for flake.homeModules.supercharged-git-commitizen
# (neusis.supercharged-git.tools.commitizen), through the umbrella.
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
            { neusis.supercharged-git.tools.commitizen = { enable = true; } // extra; }
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
      tests.hm-supercharged-git-commitizen = {
        test-installs-cz-with-git-alias = {
          expr = {
            pkg = t.hasPkg "commitizen" home.home.packages;
            alias = home.programs.git.settings.alias.cz;
            offAlias = off.programs.git.settings ? alias;
          };
          expected = {
            pkg = true;
            alias = "!cz commit";
            offAlias = false;
          };
        };
      };
    };
}
