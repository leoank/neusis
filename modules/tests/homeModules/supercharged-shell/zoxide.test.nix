# Tests for flake.homeModules.supercharged-shell-zoxide
# (neusis.supercharged-shell.tools.zoxide). Enabled through the umbrella
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
            { neusis.supercharged-shell.tools.zoxide = { enable = true; } // extra; }
          ];
        };

      home = withTool { };
      off = t.evalHm {
        pkgs = testPkgs;
        modules = [ self.homeModules.supercharged-shell ];
      };
    in
    {
      tests.hm-supercharged-shell-zoxide = {
        test-enables-zoxide-for-bash-and-zsh = {
          expr = {
            on = home.programs.zoxide.enable;
            bash = home.programs.zoxide.enableBashIntegration;
            zsh = home.programs.zoxide.enableZshIntegration;
            off = off.programs.zoxide.enable;
          };
          expected = {
            on = true;
            bash = true;
            zsh = true;
            off = false;
          };
        };
      };
    };
}
