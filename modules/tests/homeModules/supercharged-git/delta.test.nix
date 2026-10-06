# Tests for flake.homeModules.supercharged-git-delta
# (neusis.supercharged-git.tools.delta), through the umbrella.
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
            { neusis.supercharged-git.tools.delta = { enable = true; } // extra; }
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
      tests.hm-supercharged-git-delta = {
        test-enables-delta-with-git-integration = {
          expr = {
            on = home.programs.delta.enable;
            gitIntegration = home.programs.delta.enableGitIntegration;
            theme = home.programs.delta.options.syntax-theme;
            navigate = home.programs.delta.options.navigate;
            off = off.programs.delta.enable;
            failed = t.failedAssertions home;
          };
          expected = {
            on = true;
            gitIntegration = true;
            theme = "dracula";
            navigate = true;
            off = false;
            failed = [ ];
          };
        };

        test-options-replace-defaults = {
          expr = (withTool { options = { syntax-theme = "gruvbox"; }; }).programs.delta.options;
          expected = {
            syntax-theme = "gruvbox";
          };
        };
      };
    };
}
