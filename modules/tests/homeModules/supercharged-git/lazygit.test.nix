# Tests for flake.homeModules.supercharged-git-lazygit
# (neusis.supercharged-git.tools.lazygit), through the umbrella.
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
            { neusis.supercharged-git.tools.lazygit = { enable = true; } // extra; }
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
      tests.hm-supercharged-git-lazygit = {
        test-enables-lazygit-paging-through-delta = {
          expr = {
            on = home.programs.lazygit.enable;
            pager = home.programs.lazygit.settings.git.paging.pager;
            colorArg = home.programs.lazygit.settings.git.paging.colorArg;
            off = off.programs.lazygit.enable;
          };
          expected = {
            on = true;
            pager = "delta --paging=never";
            colorArg = "always";
            off = false;
          };
        };
      };
    };
}
