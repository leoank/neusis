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
  # Make sure to update the chmod commands if dataset names change
  system.activationScripts."importzfsandchmod" = ''
    ${pkgs.zfs}/bin/zpool import -fa
    chmod 0777 /datastore
  '';

}
