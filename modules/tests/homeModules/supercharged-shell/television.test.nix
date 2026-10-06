# Tests for flake.homeModules.supercharged-shell-television
# (neusis.supercharged-shell.tools.television). Enabled through the umbrella
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
            { neusis.supercharged-shell.tools.television = { enable = true; } // extra; }
          ];
        };

      home = withTool { };
      off = t.evalHm {
        pkgs = testPkgs;
        modules = [ self.homeModules.supercharged-shell ];
      };
    in
    {
      tests.hm-supercharged-shell-television = {
        test-enables-television-without-zsh-keys = {
          expr = {
            on = home.programs.television.enable;
            pkg = lib.getName home.programs.television.package;
            zsh = home.programs.television.enableZshIntegration;
            off = off.programs.television.enable;
            failed = t.failedAssertions home;
          };
          expected = {
            on = true;
            pkg = "television";
            # off by default: fzf owns Ctrl-R / Ctrl-T
            zsh = false;
            off = false;
            failed = [ ];
          };
        };

        test-package-and-zsh-are-overridable = {
          expr =
            let
              cfg = withTool {
                package = testPkgs.hello;
                enableZshIntegration = true;
              };
            in
            {
              pkg = lib.getName cfg.programs.television.package;
              zsh = cfg.programs.television.enableZshIntegration;
            };
          expected = {
            pkg = "hello";
            zsh = true;
          };
        };
      };
    };
}
