# Current 3-Drive Configuration for Oppy
# Adapted from disko-raidz2-future.nix to work with CURRENT hardware (3x Kioxia drives)
# Provides /work/ directory structure and snapshot policies WITHOUT redundancy
#
# BENEFITS NOW:
# - Get /work/ directory structure (datasets, users, scratch, tools)
# - Snapshot policies configured
# - Dataset organization matching lab policies
# - Practice with config before RAIDZ2 migration
#
# MIGRATION PATH (when 6 drives arrive):
# 1. Change mode = "" to mode = "raidz2"
# 2. Add 3 more kioxia drives (kioxia03, kioxia04, kioxia05)
# 3. Update serial numbers
# 4. Reinstall via nixos-anywhere
#
# WARNING: NO REDUNDANCY - stripe mode means any drive failure = total data loss
# This is the SAME risk as current zstore16, just with better organization

{
  # Required for testing on virtual machines
  # https://github.com/nix-community/disko/blob/master/docs/interactive-vm.md
  disko.memSize = 16384; # 16GB
  disko.devices = {
    disk = {
      # Root SSD - Samsung 4TB for OS (unchanged from current)
      ssd00 = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7KGNJ0X130041T";
        imageSize = "10G";  # For VM testing
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };

      # 3x Kioxia KCD6XLUL15T3 drives in STRIPE mode (current hardware)
      # Same drives as current zstore16, but organized as "work" pool
      kioxia00 = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-KCD6XLUL15T3_34G0A04DT5R8";  # nvme1n1
        imageSize = "1G";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "work";  # Changed from "zstore16" to match future config
              };
            };
          };
        };
      };

      kioxia01 = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-KCD6XLUL15T3_34G0A042T5R8";  # nvme4n1
        imageSize = "1G";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "work";
              };
            };
          };
        };
      };

      kioxia02 = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-KCD6XLUL15T3_34G0A05QT5R8";  # nvme7n1
        imageSize = "1G";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "work";
              };
            };
          };
        };
      };

      # Intel drives REMOVED - they were temporary, will be replaced by 3 more Kioxia
    };

    # ZFS Pool Configuration
    zpool = {
      work = {
        type = "zpool";
        mode = "";  # STRIPE mode (no redundancy) - same as current zstore16
                    # Will change to "raidz2" when we have 6 drives

        postCreateHook = "zfs list -t snapshot -H -o name | grep -E '^work@blank$' || zfs snapshot work@blank";

        rootFsOptions = {
          # Pool-level defaults
          mountpoint = "none";
          compression = "lz4";
          atime = "off";
          xattr = "sa";
          acltype = "posixacl";
          dnodesize = "auto";
          normalization = "formD";

          # IMPORTANT: ZFS dataset properties below are ONLY applied during installation.
          # They do NOT update on nixos-rebuild. To change after installation, use:
          # sudo zfs set property=value dataset
          # Example: sudo zfs set com.sun:auto-snapshot:daily=false work/scratch

          # Enable auto-snapshots by default (disable per-dataset as needed)
          "com.sun:auto-snapshot" = "true";
          "com.sun:auto-snapshot:frequent" = "true";  # Every 15 mins, keep 4
          "com.sun:auto-snapshot:hourly" = "true";    # Every hour, keep 24
          "com.sun:auto-snapshot:daily" = "true";     # Every day, keep 31
          "com.sun:auto-snapshot:weekly" = "true";    # Every week, keep 8
          "com.sun:auto-snapshot:monthly" = "true";   # Every month, keep 12
        };

        options = {
          ashift = "12";      # 4K sectors
          autotrim = "on";    # TRIM/UNMAP for SSDs
        };

        datasets = {
          # /work/datasets - Reference data (controlled by permissions)
          datasets = {
            type = "zfs_fs";
            options = {
              mountpoint = "/work/datasets";
              dedup = "off";          # Changed from current "on" - better performance
              recordsize = "1M";      # Optimize for large files
              # Keep all snapshots - critical reference data
            };
          };

          # /work/users - Active project workspaces
          users = {
            type = "zfs_fs";
            options = {
              mountpoint = "/work/users";
              dedup = "off";          # Changed from current "on" - better performance
              quota = "20T";          # Prevent runaway usage
              # Reduce snapshot frequency - active work changes often
              "com.sun:auto-snapshot:frequent" = "false";
              "com.sun:auto-snapshot:hourly" = "false";
            };
          };

          # /work/users/_archive - Archived user data
          "users/_archive" = {
            type = "zfs_fs";
            options = {
              mountpoint = "/work/users/_archive";
              compression = "zstd";   # Better compression for cold data
              # Minimal snapshots - data doesn't change
              "com.sun:auto-snapshot:frequent" = "false";
              "com.sun:auto-snapshot:hourly" = "false";
              "com.sun:auto-snapshot:daily" = "false";
              "com.sun:auto-snapshot:weekly" = "false";
            };
          };

          # /work/scratch - Temporary workspace (90-day retention)
          scratch = {
            type = "zfs_fs";
            options = {
              mountpoint = "/work/scratch";
              quota = "10T";                     # Limit scratch space
              # NO snapshots for temp data - must explicitly disable all types
              "com.sun:auto-snapshot" = "false";
              "com.sun:auto-snapshot:frequent" = "false";
              "com.sun:auto-snapshot:hourly" = "false";
              "com.sun:auto-snapshot:daily" = "false";
              "com.sun:auto-snapshot:weekly" = "false";
              "com.sun:auto-snapshot:monthly" = "false";
              sync = "disabled";                 # Max performance, data is temporary
              compression = "lz4";               # Fast compression
              recordsize = "1M";                 # Large records for big files
              atime = "on";                      # Need atime for cleanup policy
            };
          };

          # /work/tools - Shared software and models
          tools = {
            type = "zfs_fs";
            options = {
              mountpoint = "/work/tools";
              dedup = "off";          # Changed from current "on" - better performance
              recordsize = "128K";     # Mixed file sizes
              # Keep all snapshots - protect installations
            };
          };
        };
      };
    };
  };
}
