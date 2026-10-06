{pkgs, ...}: {
  home.sessionVariables.WLR_NO_HARDWARE_CURSORS = "1";
  home.sessionVariables.NIXOS_OZONE_WL = "1";

  wayland.windowManager.hyprland = {
    enable = true;
    xwayland.enable = true;
    #    enableNvidiaPatches = true;
    systemd.enable = true;
    settings = {
      source = "${./hyprland.conf}";
      exec-once = [
        pkgs.dunst
        pkgs.hyprpaper
        "${pkgs.polkit-kde-agent}/libexec/polkit-kde-authentication-agent-1"
        pkgs.firefox
      ];
    };
  };

  xdg.configFile."hypr/hyprpaper.conf".text = ''
    preload = ${./wallpapers/gruvbox_astro.jpg}
    wallpaper = ${./wallpapers/gruvbox_astro.jpg}
  '';

  # xdg.portal = {
  #   extraPortals = [ pkgs.inputs.hyprland.xdg-desktop-portal-hyprland ];
  #   configPackages = [ pkgs.inputs.hyprland.hyprland ];
  # };

  fonts.fontconfig.enable = true;

  home.packages = with pkgs; [
    hyprpaper
    xdg-desktop-portal-gtk
    xdg-desktop-portal-hyprland
    xwayland
    wayland-protocols
    wayland-utils
    wl-clipboard
    wlroots
    # notification daemon
    dunst
    libnotify
    # app launchers
    wofi
    # fonts
    nerdfonts
    meslo-lgs-nf
  ];
}
