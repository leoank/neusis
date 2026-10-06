# Tests for flake.homeModules.supercharged-git-pre-commit
# (neusis.supercharged-git.tools.pre-commit), through the umbrella.
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
            { neusis.supercharged-git.tools.pre-commit = { enable = true; } // extra; }
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
      tests.hm-supercharged-git-pre-commit = {
        test-installs-pre-commit-with-template-dir = {
          expr = {
            pkg = t.hasPkg "pre-commit" home.home.packages;
            templateDir = home.programs.git.settings.init.templateDir;
            off = off.programs.git.settings ? init;
          };
          expected = {
            pkg = true;
            templateDir = "~/.config/git/template";
            off = false;
          };
        };

        test-auto-install-off-leaves-git-init-alone = {
          expr = (withTool { autoInstall = false; }).programs.git.settings ? init;
          expected = false;
        };
      };
    };
}
