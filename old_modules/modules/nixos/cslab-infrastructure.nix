# CSLab Infrastructure Module
#
# Creates the shared directory structure and group for CSLab servers.
# Extracted from machines/oppy/cslab/infrastructure.nix.
#
# Implements:
# - imaging group for all lab members
# - /work/* directory structure (datasets, users, scratch, tools)
# - Per-user directories with correct ownership and permissions
#
# References:
# - imaging-server-maintenance/policies/user-access.md
# - imaging-server-maintenance/policies/data-storage.md
#
# Usage:
#   neusis.cslab.infrastructure = {
#     enable = true;
#     userConfigPath = ../../users/cslab.nix;
#   };

{ config, lib, pkgs, ... }:

let
  cfg = config.neusis.cslab.infrastructure;

  # Import cslab user config directly to avoid circular dependency
  # (reading config.users.users while defining users.users causes infinite recursion)
  # See this comment thread for alternatives
  # https://github.com/leoank/neusis/pull/36#discussion_r2490494840
  cslabUserConfig = import cfg.userConfigPath { inherit pkgs; };

  # Extract usernames from all user categories (admins, regulars, locked, guests)
  allCslabUsers =
    (builtins.map (u: u.username) cslabUserConfig.admins) ++
    (builtins.map (u: u.username) cslabUserConfig.regulars) ++
    (builtins.map (u: u.username) (cslabUserConfig.locked or [])) ++
    (builtins.map (u: u.username) cslabUserConfig.guests);

  # Ensure root account is never in user configuration
  # (root is a system account that must not be redefined)
  rootInConfig = builtins.elem "root" allCslabUsers;

in
{
  options.neusis.cslab.infrastructure = {
    enable = lib.mkEnableOption "CSLab directory infrastructure";

    userConfigPath = lib.mkOption {
      type = lib.types.path;
      description = "Path to the users/*.nix config file for this machine's CSLab users";
      example = "../../users/cslab.nix";
    };

    dataRoot = lib.mkOption {
      type = lib.types.str;
      default = "/work";
      description = "Root path for the CSLab directory structure (datasets, users, scratch, tools)";
    };

    imagingGid = lib.mkOption {
      type = lib.types.int;
      default = 1000;
      description = "GID for the imaging group. Must be consistent across reinstalls.";
    };

    testScriptPath = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to the test-cslab-infrastructure.sh script. Set to null to omit.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Build-time safety check: Fail if root account in config
    assertions = [
      {
        assertion = !rootInConfig;
        message = ''
          CRITICAL BUILD FAILURE: 'root' account detected in user config at ${toString cfg.userConfigPath}

          The root account is a system account that must not be redefined.

          Action required: Remove 'root' from the user config immediately.
        '';
      }
    ];

    # Create imaging group for all lab members
    users.groups.imaging = {
      gid = cfg.imagingGid;
    };

    # Add imaging group to all cslab users
    # Note: This modifies the users already created by neusisOS.mkAdmin/mkRegular
    users.users = lib.genAttrs allCslabUsers (username: {
      extraGroups = [ "imaging" ];
    });

    # Create directory structure
    # Using systemd-tmpfiles for declarative directory creation
    systemd.tmpfiles.rules = [
      # Main data directory
      "d ${cfg.dataRoot} 0750 root imaging - -"

      # Subdirectories for data organization (see policies/data-storage.md)
      "d ${cfg.dataRoot}/datasets 0770 root imaging - -"      # Reference data (group writable for REGISTRY.yaml)
      "d ${cfg.dataRoot}/users 0750 root imaging - -"         # Project workspaces
      "d ${cfg.dataRoot}/scratch 0770 root imaging - -"       # Temporary workspace (group writable)
      "d ${cfg.dataRoot}/tools 0770 root imaging - -"         # Shared software (group writable)
      "d ${cfg.dataRoot}/users/_archive 0750 root imaging - -" # Archived user data
    ];

    # Create per-user directories
    # Use systemd service to ensure ZFS is mounted before creating directories
    systemd.services.cslab-setup-directories = {
      description = "Setup CSLab user directories and permissions";
      wantedBy = [ "multi-user.target" ];
      after = [ "zfs-mount.service" ];
      requires = [ "zfs-mount.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        # Fix ZFS dataset mount point permissions (disko creates them with defaults)
        # ZFS mounts override systemd.tmpfiles, so we fix them here after mounting
        chown root:imaging ${cfg.dataRoot}/datasets ${cfg.dataRoot}/tools ${cfg.dataRoot}/users/_archive
        chmod 770 ${cfg.dataRoot}/datasets ${cfg.dataRoot}/tools
        chmod 750 ${cfg.dataRoot}/users/_archive

        # Create user-specific directories
        ${lib.concatMapStringsSep "\n" (user: ''
          # ${cfg.dataRoot}/users/<username> - project workspace
          mkdir -p ${cfg.dataRoot}/users/${user}
          chown ${user}:imaging ${cfg.dataRoot}/users/${user}
          chmod 750 ${cfg.dataRoot}/users/${user}

          # ${cfg.dataRoot}/scratch/<username> - temporary files
          mkdir -p ${cfg.dataRoot}/scratch/${user}
          chown ${user}:imaging ${cfg.dataRoot}/scratch/${user}
          chmod 750 ${cfg.dataRoot}/scratch/${user}
        '') allCslabUsers}

        echo "CSLab user directories created/verified for: ${lib.concatStringsSep ", " allCslabUsers}"
      '';
    };

    # Add test script to system PATH (when provided)
    environment.systemPackages = lib.mkIf (cfg.testScriptPath != null) [
      (pkgs.writeScriptBin "test-cslab-infrastructure.sh"
        (builtins.readFile cfg.testScriptPath))
    ];
  };
}
