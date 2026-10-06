# Tests for flake.homeModules.brave: brave via programs.chromium with the
# curated extension set; useHomebrew skips the package on Darwin only.
{ self, ... }:
{
  perSystem =
    { lib, testPkgs, ... }:
    let
      t = self.neusis.lib.tests;
      brave =
        extra:
        t.evalHm {
          pkgs = testPkgs;
          modules = [
            self.homeModules.brave
            { neusis.brave = { enable = true; } // extra; }
          ];
        };
      home = brave { };
      ids = cfg: map (e: e.id) cfg.programs.chromium.extensions;
    in
    {
      tests.hm-brave = {
        test-enable-installs-brave-with-curated-extensions = {
          expr = {
            on = home.programs.chromium.enable;
            pkg = lib.getName home.programs.chromium.package;
            extensions = ids home;
            args = home.programs.chromium.commandLineArgs;
            failed = t.failedAssertions home;
          };
          expected = {
            on = true;
            pkg = "brave";
            extensions = [
              "cjpalhdlnbpafiamejdnhcphjbkeiagm"
              "eimadpbcbfnmbkopoojfekhnkhdbieeh"
              "faeadnfmdfamenfhaipofoffijhlnkif"
              "cdglnehniifkbagbbombnjghhcihifij"
            ];
            args = [ "--disable-features=WebRtcAllowInputVolumeAdjustment" ];
            failed = [ ];
          };
        };

        test-extra-extensions-and-args-are-appended = {
          expr =
            let
              cfg = brave {
                extraExtensions = [ { id = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"; } ];
                extraCommandLineArgs = [ "--foo" ];
              };
            in
            {
              lastExtension = lib.last (ids cfg);
              count = builtins.length (ids cfg);
              args = cfg.programs.chromium.commandLineArgs;
            };
          expected = {
            lastExtension = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
            count = 5;
            args = [
              "--disable-features=WebRtcAllowInputVolumeAdjustment"
              "--foo"
            ];
          };
        };

        test-use-homebrew-skips-the-package-on-darwin-only = {
          expr =
            let
              cfg = brave { useHomebrew = true; };
            in
            {
              stillBrave = lib.getName cfg.programs.chromium.package == "brave";
              extensionsKept = builtins.length (ids cfg);
            };
          expected = {
            # Darwin: the cask provides the binary; Linux: flag is ignored
            stillBrave = !testPkgs.stdenv.isDarwin;
            extensionsKept = 4;
          };
        };

        test-disabled-leaves-chromium-off = {
          expr =
            (t.evalHm {
              pkgs = testPkgs;
              modules = [ self.homeModules.brave ];
            }).programs.chromium.enable;
          expected = false;
        };
      };
    };
}
