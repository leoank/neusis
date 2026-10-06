{
  inputs,
  pkgs,
  ...
}:
let
  hide_window_kitty = if pkgs.stdenv.isDarwin then "titlebar-only" else "yes";
  atuin_enable = if pkgs.stdenv.isDarwin then true else false;
in
{
  home.packages = [
    (pkgs.writers.writePython3Bin "gclb" { } ./gclb.py)
  ];

  programs = {
    atuin = {
      enable = atuin_enable;
      daemon.enable = true;
      flags = [
        "--disable-up-arrow"
      ];
      settings = {
        auto_sync = true;
        sync_frequency = "5m";
        sync_address = "https://api.atuin.sh";
        search_mode = "fuzzy";
        enter_accept = false;
      };
      enableZshIntegration = true;
    };

    wezterm = {
      enable = true;
      package = pkgs.wezterm;
      enableZshIntegration = false;
      extraConfig = builtins.readFile ./wezterm.lua;
    };

    kitty = {
      enable = true;
      settings = {
        hide_window_decorations = hide_window_kitty;
        draw_minimal_borders = "yes";
      };

    };

    zellij = {
      enable = true;
      settings = {
        theme = "gruvbox-dark";
        simplified_ui = true;
        default_mode = "locked";
      };
      enableZshIntegration = false;
    };
  };
  xdg.configFile = {
    "zellij/config.kdl".source = ./zellij.kdl;
    "zellij/layouts/default.kdl".source = ./zellij_layout.kdl;
  };
}
