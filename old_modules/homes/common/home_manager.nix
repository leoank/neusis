{ outputs, ... }:
{
  nixpkgs = {
    overlays = builtins.attrValues outputs.overlays;
    config.allowUnfree = true;
  };

  home.stateVersion = "25.11";

  programs.home-manager.enable = true;
}
