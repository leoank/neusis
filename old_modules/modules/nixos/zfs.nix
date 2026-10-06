{ lib, config, ... }:
{
  options.neusis.zfs.autoSnapshot.enable =
    lib.mkEnableOption "ZFS auto-snapshots with CSLab retention policy";

  config = {
    boot.kernelParams = [ "nohibernate" ];
    boot.initrd.supportedFilesystems = [ "zfs" ];
    boot.supportedFilesystems = [ "zfs" ];
    boot.zfs.forceImportRoot = true;
    boot.zfs.forceImportAll = true;
    services = {
      zfs.autoScrub.enable = true;
      zfs.trim.enable = true;
    };

    # CSLab retention policy: opt-in per machine
    services.zfs.autoSnapshot = lib.mkIf config.neusis.zfs.autoSnapshot.enable {
      enable = true;
      frequent = 4;   # Keep 4 snapshots (15 min intervals)
      hourly = 24;    # Keep 24 snapshots
      daily = 31;     # Keep 31 snapshots
      weekly = 8;     # Keep 8 snapshots
      monthly = 12;   # Keep 12 snapshots
    };
  };
}
