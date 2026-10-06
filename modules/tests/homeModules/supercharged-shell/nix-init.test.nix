# Tests for flake.homeModules.supercharged-shell-nix-init
# (neusis.supercharged-shell.tools.nix-init). Enabled through the umbrella
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
            { neusis.supercharged-shell.tools.nix-init = { enable = true; } // extra; }
          ];
        };

      home = withTool { };
      off = t.evalHm {
        pkgs = testPkgs;
        modules = [ self.homeModules.supercharged-shell ];
      };
    in
    {
      tests.hm-supercharged-shell-nix-init = {
        test-enables-nix-init-with-maintainers = {
          expr = {
            on = (withTool { maintainers = [ "ank" ]; }).programs.nix-init.enable;
            maintainers = (withTool { maintainers = [ "ank" ]; }).programs.nix-init.settings.maintainers;
            defaultMaintainers = home.programs.nix-init.settings.maintainers;
            off = off.programs.nix-init.enable;
          };
          expected = {
            on = true;
            maintainers = [ "ank" ];
            defaultMaintainers = [ ];
            off = false;
          };
        };
      };
    };
}
