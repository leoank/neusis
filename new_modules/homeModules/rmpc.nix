# Neusis rmpc home-manager module.
#
# Thin wrapper around `programs.rmpc` that exposes the most-changed
# knobs (mpd address, volume step, max FPS) as structured options and
# uses them to render the legacy RON config the rogue `home.nix` had
# inline. Override `config` to swap in your own RON wholesale.
{ ... }:
{
  flake.homeModules.rmpc =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.neusis.rmpc;

      defaultConfig = ''
        (
          address: "${cfg.address}",
          password: None,
          theme: None,
          cache_dir: None,
          on_song_change: None,
          volume_step: ${toString cfg.volumeStep},
          max_fps: ${toString cfg.maxFps},
          scrolloff: 0,
          wrap_navigation: false,
          enable_mouse: true,
          enable_config_hot_reload: true,
          select_current_song_on_change: false,
          browser_song_sort: [Disc, Track, Artist, Title],
          album_art: (
              method: Auto,
              max_size_px: (width: 600, height: 600),
              disabled_protocols: ["http://", "https://"],
              vertical_align: Center,
              horizontal_align: Center,
          ),
        )
      '';
    in
    {
      options.neusis.rmpc = {
        enable = lib.mkEnableOption "rmpc (Rust MPD client)";

        address = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1:6600";
          description = ''
            mpd server `host:port`. Substituted into the default
            config; ignored if `config` is overridden.
          '';
        };

        volumeStep = lib.mkOption {
          type = lib.types.ints.between 1 100;
          default = 5;
          description = "Volume adjustment step (percent). Default config only.";
        };

        maxFps = lib.mkOption {
          type = lib.types.ints.positive;
          default = 30;
          description = "Max render frames per second. Default config only.";
        };

        config = lib.mkOption {
          type = lib.types.str;
          default = defaultConfig;
          defaultText = lib.literalMD ''
            Neusis default — substitutes `address`, `volumeStep`, and
            `maxFps` into the legacy RON config.
          '';
          description = ''
            Full RON config written to `~/.config/rmpc/config.ron`.
            Overriding bypasses the structured options above.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        programs.rmpc = {
          enable = true;
          inherit (cfg) config;
        };
      };
    };
}
