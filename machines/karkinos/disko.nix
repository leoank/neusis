{
  disko.memSize = 16384; # 16GB
  disko.devices = {
    disk = {
      # SSD cluster
      ssd0 = {
        type = "disk";
        device = "/dev/nvme1n1";
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
        device = "/dev/nvme0n1";
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
        device = "/dev/nvme2n1";
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
        device = "/dev/sda";
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
        device = "/dev/sdb";
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
        device = "/dev/sdc";
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
        rootFsOptions = {
          # Make sure these options are correct
          canmount = "on";
          acltype = "posixacl";
          dnodesize = "auto";
          normalization = "formD";
          atime = "off";
          compression = "lz4";
          mountpoint = "none";
          xattr = "sa";
          "com.sun:auto-snapshot" = "false";
        };
        options.ashift = "12";
        options.autotrim = "on";

        datasets = {
          "root" = {
            type = "zfs_fs";
            mountpoint = "/";
            options."com.sun:auto-snapshot" = "false";
          };
          # FIXME: This mounts after user dir creations and overwrites with blank home dir
          # "home" = { type = "zfs_fs";
          #   mountpoint = "/home";
          #   options."com.sun:auto-snapshot" = "true";
          # };
          "nix" = {
            type = "zfs_fs";
            mountpoint = "/nix";
            options."com.sun:auto-snapshot" = "false";
          };
        };
      };

      zstore = {
        type = "zpool";
        mode = "";
        rootFsOptions = {
          # Make sure these options are correct
          canmount = "on";
          acltype = "posixacl";
          dnodesize = "auto";
          normalization = "formD";
          atime = "off";
          compression = "lz4";
          mountpoint = "none";
          xattr = "sa";
          "com.sun:auto-snapshot" = "false";
        };
        options.ashift = "12";
        options.autotrim = "on";

        datasets = {
          datastore = {
            type = "zfs_fs";
            mountpoint = "/datastore";
            postCreateHook = "zfs snapshot zstore/datastore@blank";
          };
        };
      };
    };
  };
}
