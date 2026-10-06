# https://github.com/Mic92/nixos-shell
{ pkgs, ... }:
{
  boot.kernelPackages = pkgs.linuxPackages_latest;
  services.openssh.enable = true;
  documentation.enable = false;
  #services.xserver.enable = true;
  #virtualisation.graphics = true;
}
