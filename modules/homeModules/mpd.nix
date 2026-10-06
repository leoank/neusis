# Neusis mpd home-manager module.
#
# Wraps `services.mpd` with platform-aware log/playlist paths and the
# directory-creation activation script the legacy `rogue.nix` had
# inline. Opt-in via `neusis.mpd.enable`.
#
# Works on Darwin (launchd via home-manager) and Linux (systemd user
# service via home-manager). The default log path is
# `~/Library/Logs/mpd/log.txt` on Darwin and `~/.local/state/mpd/log`
# on Linux.
{ ... }:
{
  flake.homeModules.mpd =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.neusis.mpd;
      defaultLogFile =
        if pkgs.stdenv.isDarwin then
          "${config.home.homeDirectory}/Library/Logs/mpd/log.txt"
        else
          "${config.home.homeDirectory}/.local/state/mpd/log";
    in
    {
      options.neusis.mpd = {
        enable = lib.mkEnableOption "the MPD music daemon home-manager service";

        musicDirectory = lib.mkOption {
          type = lib.types.str;
          default = "${config.home.homeDirectory}/Music";
          defaultText = lib.literalExpression ''"''${config.home.homeDirectory}/Music"'';
          description = "Music library root passed to mpd.";
        };

        logFile = lib.mkOption {
          type = lib.types.str;
          default = defaultLogFile;
          defaultText = lib.literalMD ''
            `~/Library/Logs/mpd/log.txt` on Darwin,
            `~/.local/state/mpd/log` on Linux.
          '';
          description = ''
            Path mpd writes its log to. The parent directory and the
            file itself are created in a home-manager activation step
            so mpd doesn't fail on first start.
          '';
        };

        playlistDirectory = lib.mkOption {
          type = lib.types.str;
          default = "${config.home.homeDirectory}/.local/share/mpd/playlists";
          defaultText = lib.literalExpression ''"''${config.home.homeDirectory}/.local/share/mpd/playlists"'';
          description = "Playlist directory. Created via home.activation if missing.";
        };

        extraConfig = lib.mkOption {
          type = lib.types.lines;
          default = "";
          description = ''
            Extra mpd.conf snippets appended after the auto-generated
            `log_file` line. Passed through to
            `services.mpd.extraConfig` verbatim.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        services.mpd = {
          enable = true;
          inherit (cfg) musicDirectory;
          extraConfig = ''
            log_file       "${cfg.logFile}"
          ''
          + cfg.extraConfig;
        };

        home.activation.mpd_dirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          mkdir -p "$(dirname ${lib.escapeShellArg cfg.logFile})"
          touch ${lib.escapeShellArg cfg.logFile}
          mkdir -p ${lib.escapeShellArg cfg.playlistDirectory}
        '';
      };
    };
}
