# Tests for flake.homeModules.supercharged-git-jujutsu
# (neusis.supercharged-git.tools.jujutsu), through the umbrella.
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
            { neusis.supercharged-git.tools.jujutsu = { enable = true; } // extra; }
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
      tests.hm-supercharged-git-jujutsu = {
        test-enables-jj-with-git-identity = {
          expr = {
            on = home.programs.jujutsu.enable;
            settings = home.programs.jujutsu.settings;
            off = off.programs.jujutsu.enable;
            failed = t.failedAssertions home;
          };
          expected = {
            on = true;
            settings = {
              user = {
                name = "Alice Fixture";
                email = "alice@example.com";
              };
              ui.default-command = "log";
            };
            off = false;
            failed = [ ];
          };
        };

        test-extra-settings-merge-deeply = {
          expr = (withTool { extraSettings.ui.paginate = "never"; }).programs.jujutsu.settings.ui;
          expected = {
            default-command = "log";
            paginate = "never";
          };
        };
      };
    };
}
