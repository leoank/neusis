# Tests for flake.neusis.features.hm.mac-app-util: pulls in the
# mac-app-util home-manager module (Spotlight trampolines for nix apps).
{ self, ... }:
{
  perSystem =
    { lib, testPkgs, ... }:
    let
      t = self.neusis.lib.tests;
      isDarwin = testPkgs.stdenv.isDarwin;
      home = t.evalHm {
        pkgs = testPkgs;
        modules = [ self.neusis.features.hm.mac-app-util ];
      };
    in
    {
      tests.feature-hm-mac-app-util = {
        test-adds-trampoline-activation = {
          expr =
            if isDarwin then
              {
                activation = home.home.activation ? trampolineApps;
                options = home.targets.darwin ? mac-app-util;
                failed = t.failedAssertions home;
              }
            else
              {
                activation = true;
                options = true;
                failed = [ ];
              };
          expected = {
            activation = true;
            options = true;
            failed = [ ];
          };
        };
      };
    };
}
