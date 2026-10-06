{
  config,
  pkgs,
  user,
  ...
}: {
  # Fully declarative dock using the latest from Nix Store
  local.dock.enable = true;
  local.dock.entries = [
    {path = "/Applications/Firefox.app/";}
    {path = "${pkgs.wezterm}/Applications/Wezterm.app/";}
    {path = "${pkgs.emacs}/Applications/Emacs.app/";}
    {path = "/Applications/Zotero.app/";}
    {
      path = "${config.users.users.${user}.home}/.local/share/";
      section = "others";
      options = "--sort name --view grid --display folder";
    }
    {
      path = "${config.users.users.${user}.home}/Downloads";
      section = "others";
      options = "--sort name --view grid --display stack";
    }
  ];
}
