{
  disko.memSize = 16384; # 16GB
  disko.devices = {
    disk = {
      # SSD cluster
      ssd0 = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7KGNJ0WC00172Y";
        imageSize = "3G";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "zroot";
              };
            };
          };
        };
      };
      ssd1 = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7KGNJ0X145183K";
        imageSize = "3G";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "zroot";
              };
            };
          };
        };
      };
      ssd2 = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7KGNJ0X151766K";
        imageSize = "3G";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "zroot";
              };
            };
          };
        };
      };

      # HDD cluster
      hdd0 = {
        type = "disk";
        device = "/dev/disk/by-id/ata-TOSHIBA_HDWG51GUZSVB_34A0A00AF1FJ";
        imageSize = "1G";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "zstore";
              };
            };
          };
        };
      };

      hdd1 = {
        type = "disk";
        device = "/dev/disk/by-id/ata-TOSHIBA_HDWG51GUZSVB_34M0A02EF1FJ";
        imageSize = "1G";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "zstore";
              };
            };
          };
        };
      };

      hdd2 = {
        type = "disk";
        device = "/dev/disk/by-id/ata-TOSHIBA_HDWG51GUZSVB_3490A031F1FJ";
        imageSize = "1G";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "zstore";
              };
            };
          };
        };
      };
    };
    # Z pool definitions
    zpool = {
      zroot = {
        type = "zpool";
        mode = "";
        postCreateHook = "zfs list -t snapshot -H -o name | grep -E '^zroot@blank$' || zfs snapshot zroot@blank";
        rootFsOptions = {
          # Make sure these options are correct
          mountpoint = "none";
          acltype = "posixacl";
          dnodesize = "auto";
          normalization = "formD";
          atime = "off";
          compression = "lz4";
          xattr = "sa";
          "com.sun:auto-snapshot" = "false";
        };
        options.ashift = "12";
        options.autotrim = "on";

        datasets = {
          "local/root" = {
            type = "zfs_fs";
            mountpoint = "/";
          };

          "local/nix" = {
            type = "zfs_fs";
            options.mountpoint = "/nix";
            mountpoint = "/nix";
          };

          # This create issues in a vm and possible on real machine too
          # But the real machine is using old config and we don't to destroy the current disks layout
          # So, I am keeping this here as a reference.
          "local/home" = {
            type = "zfs_fs";
            options.mountpoint = "/home";
            mountpoint = "/home";
          };
        };
      };

      zstore = {
        type = "zpool";
        mode = "";
        postCreateHook = "zfs list -t snapshot -H -o name | grep -E '^zstore@blank$' || zfs snapshot zstore@blank";
        rootFsOptions = {
          # Make sure these options are correct
          mountpoint = "none";
          acltype = "posixacl";
          dnodesize = "auto";
          normalization = "formD";
          atime = "off";
          compression = "lz4";
          xattr = "sa";
          "com.sun:auto-snapshot" = "true";
        };
        options.ashift = "12";
        options.autotrim = "on";

        datasets = {
          # /work - Parent dataset
          work = {
            type = "zfs_fs";
            options.mountpoint = "/work";
          };

          # /work/datasets - Reference data
          "work/datasets" = {
            type = "zfs_fs";
            options = {
              mountpoint = "/work/datasets";
              recordsize = "1M";      # Optimize for large files
            };
          };

          # /work/users - Active project workspaces
          "work/users" = {
            type = "zfs_fs";
            options = {
              mountpoint = "/work/users";
              quota = "20T";
              "com.sun:auto-snapshot:frequent" = "false";
              "com.sun:auto-snapshot:hourly" = "false";
            };
          };

          # /work/users/_archive - Archived user data
          "work/users/_archive" = {
            type = "zfs_fs";
            options = {
              mountpoint = "/work/users/_archive";
              compression = "zstd";
              "com.sun:auto-snapshot:frequent" = "false";
              "com.sun:auto-snapshot:hourly" = "false";
              "com.sun:auto-snapshot:daily" = "false";
              "com.sun:auto-snapshot:weekly" = "false";
            };
          };

          # /work/scratch - Temporary workspace (90-day retention)
          "work/scratch" = {
            type = "zfs_fs";
            options = {
              mountpoint = "/work/scratch";
              quota = "10T";
              # NO snapshots for temp data - explicitly disable parent and all tiers.
              # Defense-in-depth: if pool-level per-tier properties are ever added
              # (as in Oppy's disko.nix), they would override a dataset-level parent
              # false. Disabling each tier prevents unwanted snapshots regardless.
              "com.sun:auto-snapshot" = "false";
              "com.sun:auto-snapshot:frequent" = "false";
              "com.sun:auto-snapshot:hourly" = "false";
              "com.sun:auto-snapshot:daily" = "false";
              "com.sun:auto-snapshot:weekly" = "false";
              "com.sun:auto-snapshot:monthly" = "false";
              sync = "disabled";
              compression = "lz4";
              recordsize = "1M";
              atime = "on";
            };
          };

          # /work/tools - Shared software and models
          "work/tools" = {
            type = "zfs_fs";
            options = {
              mountpoint = "/work/tools";
              recordsize = "128K";
            };
          };
        };
      };
    };
  };
}
