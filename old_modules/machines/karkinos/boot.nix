{ pkgs, ... }:
{
  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # https://github.com/nix-community/disko/issues/581
  # This is required because we are not using legacy mounts
  # We are not using it right now because of #359
  # boot.zfs.extraPools = [
  #   "zroot"
  #   "zstore"
  # ];

  # https://discourse.nixos.org/t/cannot-import-zfs-pool-at-boot/4805/18
  #boot.zfs.devNodes = "/dev/disk/by-id";

  # Zfs second pool import issue: https://github.com/nix-community/disko/issues/359
  system.activationScripts."importzfs" = ''
    ${pkgs.zfs}/bin/zpool import -fa
    chmod 0777 /work
    chmod 0777 -R /work/datasets
    chmod 0777 -R /work/scratch
    chmod 0777 -R /work/tools
  '';

}
