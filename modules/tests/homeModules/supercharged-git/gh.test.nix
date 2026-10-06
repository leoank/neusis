# Tests for flake.homeModules.supercharged-git-gh
# (neusis.supercharged-git.tools.gh), through the umbrella.
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
            { neusis.supercharged-git.tools.gh = { enable = true; } // extra; }
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
      tests.hm-supercharged-git-gh = {
        test-enables-gh-with-default-extensions = {
          expr = {
            on = home.programs.gh.enable;
            extensions = t.pkgNames home.programs.gh.extensions;
            credentialHelper = home.programs.gh.gitCredentialHelper.enable;
            off = off.programs.gh.enable;
            failed = t.failedAssertions home;
          };
          expected = {
            on = true;
            extensions = [ "gh-dash" ];
            credentialHelper = true;
            off = false;
            failed = [ ];
          };
        };

        test-extensions-are-overridable = {
          expr = (withTool { extensions = [ ]; }).programs.gh.extensions;
          expected = [ ];
        };
      };
    };
}
