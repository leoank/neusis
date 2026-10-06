# Tests for flake.homeModules.hammerspoon: links the bundled config dir
# into ~/.config/hammerspoon on Darwin; no-op on Linux.
{ self, ... }:
{
  perSystem =
    { lib, testPkgs, ... }:
    let
      t = self.neusis.lib.tests;
      hs =
        extra:
        t.evalHm {
          pkgs = testPkgs;
          modules = [
            self.homeModules.hammerspoon
            { neusis.hammerspoon = { enable = true; } // extra; }
          ];
        };
      home = hs { };
      isDarwin = testPkgs.stdenv.isDarwin;
      file = cfg: cfg.home.file.".config/hammerspoon";
    in
    {
      tests.hm-hammerspoon = {
        test-darwin-links-bundled-config-recursively = {
          expr =
            if isDarwin then
              {
                present = home.home.file ? ".config/hammerspoon";
                recursive = (file home).recursive;
                hasInit = builtins.pathExists ((file home).source + "/init.lua");
                hasSpoons = builtins.pathExists ((file home).source + "/Spoons");
              }
            else
              {
                present = home.home.file ? ".config/hammerspoon";
                recursive = true;
                hasInit = true;
                hasSpoons = true;
              };
          expected = {
            present = isDarwin;
            recursive = true;
            hasInit = true;
            hasSpoons = true;
          };
        };

        test-config-dir-is-overridable = {
          expr =
            if isDarwin then baseNameOf (toString (file (hs { configDir = ../_fixtures; })).source) else "_fixtures";
          expected = "_fixtures";
        };

        test-disabled-links-nothing = {
          expr =
            (t.evalHm {
              pkgs = testPkgs;
              modules = [ self.homeModules.hammerspoon ];
            }).home.file
            ? ".config/hammerspoon";
          expected = false;
        };
      };
    };
}
