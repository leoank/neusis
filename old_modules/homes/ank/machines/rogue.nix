{
  config,
  pkgs,
  inputs,
  outputs,
  lib,
  ...
}:
{
  imports = [
    ../../common/home_manager.nix
    ../../common/dev
    ../../common/dev/kalam.nix
    ../../common/themes
    ../../common/browsers/brave.nix
    ../../common/dev/editors.nix
    ../configs/terminal/tmux.nix
    ../configs/agent_harness/cli_agents.nix
    ../configs/terminal/zsh.nix
    (import ../../common/dev/git.nix {
      username = "Ankur Kumar";
      userEmail = "ank@leoank.me";
      id_ed25519_pub = builtins.readFile ../id_ed25519.pub;
    })
  ];

  # Configure music
  services.mpd = {
    enable = true;
    musicDirectory = "${config.home.homeDirectory}/Music";
    extraConfig = ''
      log_file       "${config.home.homeDirectory}/Library/Logs/mpd/log.txt"
    '';
  };

  # Required for mpd to work
  home.activation = {
    mpd_dir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "${config.home.homeDirectory}/Library/Logs/mpd"
      touch "${config.home.homeDirectory}/Library/Logs/mpd/logs.txt"
      mkdir -p "${config.home.homeDirectory}/.local/share/mpd/playlists"
    '';
  };

  programs.rmpc = {
    enable = true;
    config = ''
      (
        address: "127.0.0.1:6600",
        password: None,
        theme: None,
        cache_dir: None,
        on_song_change: None,
        volume_step: 5,
        max_fps: 30,
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
      ),
    '';
  };

  # Configure nixpkgs
  nixpkgs = {
    # You can add overlays here
    overlays = builtins.attrValues outputs.overlays;
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
    };
  };

  home.username = "ank";
  home.homeDirectory = "/Users/ank";
  home.packages = import ../packages.nix { inherit pkgs inputs outputs; };

  # Add hammerspoon config
  xdg.configFile."hammerspoon" = {
    source = ../configs/hammerspoon;
    recursive = true;
  };
}
