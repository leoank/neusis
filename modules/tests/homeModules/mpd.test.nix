# Tests for flake.homeModules.mpd: services.mpd with a platform-specific
# log file and an activation step that creates the log/playlist dirs.
{ self, ... }:
{
  perSystem =
    { lib, testPkgs, ... }:
    let
      t = self.neusis.lib.tests;
      mpd =
        extra:
        t.evalHm {
          pkgs = testPkgs;
          modules = [
            self.homeModules.mpd
            { neusis.mpd = { enable = true; } // extra; }
          ];
        };
      home = mpd { };
      homeDir = home.home.homeDirectory;
      defaultLog =
        if testPkgs.stdenv.isDarwin then "${homeDir}/Library/Logs/mpd/log.txt" else "${homeDir}/.local/state/mpd/log";
    in
    {
      tests.hm-mpd = {
        test-enable-configures-mpd-with-platform-log = {
          expr = {
            on = home.services.mpd.enable;
            music = home.services.mpd.musicDirectory;
            logLine = lib.hasInfix ''log_file       "${defaultLog}"'' home.services.mpd.extraConfig;
            activation = home.home.activation ? mpd_dirs;
            afterWrite = builtins.elem "writeBoundary" home.home.activation.mpd_dirs.after;
            createsPlaylists = lib.hasInfix "${homeDir}/.local/share/mpd/playlists" home.home.activation.mpd_dirs.data;
            failed = t.failedAssertions home;
          };
          expected = {
            on = true;
            music = "${homeDir}/Music";
            logLine = true;
            activation = true;
            afterWrite = true;
            createsPlaylists = true;
            failed = [ ];
          };
        };

        test-paths-and-extra-config-are-overridable = {
          expr =
            let
              cfg = mpd {
                musicDirectory = "/srv/music";
                logFile = "/var/log/mpd.log";
                playlistDirectory = "/srv/playlists";
                extraConfig = "audio_output { type \"null\" }";
              };
            in
            {
              music = cfg.services.mpd.musicDirectory;
              log = lib.hasInfix ''log_file       "/var/log/mpd.log"'' cfg.services.mpd.extraConfig;
              extra = lib.hasSuffix "audio_output { type \"null\" }" cfg.services.mpd.extraConfig;
              playlists = lib.hasInfix "/srv/playlists" cfg.home.activation.mpd_dirs.data;
            };
          expected = {
            music = "/srv/music";
            log = true;
            extra = true;
            playlists = true;
          };
        };

        test-disabled-leaves-mpd-off = {
          expr =
            let
              cfg = t.evalHm {
                pkgs = testPkgs;
                modules = [ self.homeModules.mpd ];
              };
            in
            {
              on = cfg.services.mpd.enable;
              activation = cfg.home.activation ? mpd_dirs;
            };
          expected = {
            on = false;
            activation = false;
          };
        };
      };
    };
}
