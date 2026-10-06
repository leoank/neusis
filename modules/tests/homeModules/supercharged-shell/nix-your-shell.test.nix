# Tests for flake.homeModules.supercharged-shell-nix-your-shell
# (neusis.supercharged-shell.tools.nix-your-shell). Enabled through the umbrella
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
            { neusis.supercharged-shell.tools.nix-your-shell = { enable = true; } // extra; }
          ];
        };

      home = withTool { };
      off = t.evalHm {
        pkgs = testPkgs;
        modules = [ self.homeModules.supercharged-shell ];
      };
    in
    {
      tests.hm-supercharged-shell-nix-your-shell = {
        test-enables-nix-your-shell-for-zsh = {
          expr = {
            on = home.programs.nix-your-shell.enable;
            zsh = home.programs.nix-your-shell.enableZshIntegration;
            off = off.programs.nix-your-shell.enable;
          };
          expected = {
            on = true;
            zsh = true;
            off = false;
          };
        };
      };
    };
}
