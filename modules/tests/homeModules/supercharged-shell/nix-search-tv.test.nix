# Tests for flake.homeModules.supercharged-shell-nix-search-tv
# (neusis.supercharged-shell.tools.nix-search-tv). Enabled through the umbrella
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
            { neusis.supercharged-shell.tools.nix-search-tv = { enable = true; } // extra; }
          ];
        };

      home = withTool { };
      off = t.evalHm {
        pkgs = testPkgs;
        modules = [ self.homeModules.supercharged-shell ];
      };
    in
    {
      tests.hm-supercharged-shell-nix-search-tv = {
        test-enables-nix-search-tv-with-television-channel = {
          expr = {
            on = home.programs.nix-search-tv.enable;
            tv = home.programs.nix-search-tv.enableTelevisionIntegration;
            off = off.programs.nix-search-tv.enable;
            failed = t.failedAssertions home;
          };
          expected = {
            on = true;
            tv = true;
            off = false;
            failed = [ ];
          };
        };
      };
    };
}
