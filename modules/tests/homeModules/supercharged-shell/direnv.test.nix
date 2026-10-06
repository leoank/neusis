# Tests for flake.homeModules.supercharged-shell-direnv
# (neusis.supercharged-shell.tools.direnv). Enabled through the umbrella
# import but without the umbrella's own `enable` — tools are independent.
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
            self.homeModules.supercharged-shell
            { neusis.supercharged-shell.tools.direnv = { enable = true; } // extra; }
          ];
        };

      home = withTool { };
      off = t.evalHm {
        pkgs = testPkgs;
        modules = [ self.homeModules.supercharged-shell ];
      };
    in
    {
      tests.hm-supercharged-shell-direnv = {
        test-enables-direnv-with-nix-direnv = {
          expr = {
            on = home.programs.direnv.enable;
            nixDirenv = home.programs.direnv.nix-direnv.enable;
            zsh = home.programs.direnv.enableZshIntegration;
            off = off.programs.direnv.enable;
          };
          expected = {
            on = true;
            nixDirenv = true;
            zsh = true;
            off = false;
          };
        };
      };
    };
}
