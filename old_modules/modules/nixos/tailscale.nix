{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.neusis.tailscale;
  forceClaimHostName =
    mkIf
      (
        cfg.forceHostName
        && cfg.clientIdFile != null
        && cfg.clientSecretFile != null
        && cfg.tailnetOrg != null
        && cfg.hostName != null
      )
      ''
        ${pkgs.bash}/bin/bash ${./tailscale-force-claim.sh}
      '';

  disableKeyExpiryScript =
    mkIf
      (
        cfg.disableKeyExpiry
        && cfg.clientIdFile != null
        && cfg.clientSecretFile != null
        && cfg.tailnetOrg != null
        && cfg.hostName != null
      )
      ''
        ${pkgs.bash}/bin/bash ${./tailscale-disable-key-expiry.sh}
      '';
in
{
  options = {
    neusis.tailscale = {
      enable = mkEnableOption "Enable Neusis tailscale config";

      authkey_file = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Path to the age tsauthkey file.";
      };

      persistent_authkey_file = mkOption {
        type = types.path;
        default = ../../secrets/common/persistent_tsauthkey.age;
        description = "Path to the persistent age tsauthkey file.";
      };

      ephemeral_authkey_file = mkOption {
        type = types.path;
        default = ../../secrets/common/ephemeral_tsauthkey.age;
        description = "Path to the ephemeral age tsauthkey file.";
      };

      isPersistent = mkOption {
        type = types.bool;
        default = false;
        description = "Use userspace networking.";
      };

      isUserSpace = mkOption {
        type = types.bool;
        default = false;
        description = "Use userspace networking.";
      };

      hostName = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Custom hostname to use.";
      };

      forceHostName = mkOption {
        type = types.nullOr types.bool;
        default = true;
        description = ''
          Force claim hostname on the tailnet.
          This will ensure the current device gets the exact hostname by:
          1. Renaming any conflicting devices to hostname-old, hostname-old2, etc.
          2. Then setting the current device to the specified hostname.
          All devices are preserved (nothing gets deleted).
        '';
      };

      clientIdFile = mkOption {
        type = types.nullOr types.path;
        default = ../../secrets/common/tsclient.age;
        description = "Path to the age file containing Tailscale OAuth client ID.";
      };

      clientSecretFile = mkOption {
        type = types.nullOr types.path;
        default = ../../secrets/common/tssecret.age;
        description = "Path to the age file containing Tailscale OAuth client secret.";
      };

      tailnetOrg = mkOption {
        type = types.nullOr types.str;
        default = "leoank.github";
        description = "Tailscale organization/tailnet name.";
      };

      disableKeyExpiry = mkOption {
        type = types.bool;
        default = false;
        description = "Disable key expiry for the device after connection.";
      };

    };
  };

  config = mkIf cfg.enable {

    # make the tailscale command usable to users
    environment.systemPackages = [ pkgs.tailscale ];

    # add agenix secrets
    age.secrets = mkMerge [
      {
        tsauthkey.file =
          if cfg.authkey_file != null then
            cfg.authkey_file
          else if cfg.isPersistent then
            cfg.persistent_authkey_file
          else
            cfg.ephemeral_authkey_file;
      }
      (mkIf (cfg.forceHostName && cfg.clientIdFile != null && cfg.clientSecretFile != null) {
        ts-client-id.file = cfg.clientIdFile;
        ts-client-secret.file = cfg.clientSecretFile;
      })
    ];

    # enable the tailscale service
    services.tailscale = {
      enable = true;
      authKeyFile = config.age.secrets.tsauthkey.path;
      extraUpFlags = mkIf (cfg.hostName != null) [
        "--hostname"
        "${cfg.hostName}"
      ];
    };

    # Add systemd service for force hostname functionality
    systemd.services.tailscale-force-claim =
      mkIf
        (
          cfg.forceHostName
          && cfg.clientIdFile != null
          && cfg.clientSecretFile != null
          && cfg.tailnetOrg != null
          && cfg.hostName != null
        )
        {
          description = "Force claim Tailscale hostname";
          after = [
            "tailscaled-autoconnect.service"
            "tailscale-disable-key-expiry.service"
          ];
          wants = [ "tailscaled-autoconnect.service" ];
          wantedBy = [ "multi-user.target" ];
          path = [
            pkgs.bash
            pkgs.tailscale
            pkgs.jq
            pkgs.curl
          ];
          script = forceClaimHostName;
          serviceConfig = {
            Type = "oneshot";
            Environment = [
              "TS_CLIENT_ID_FILE=${config.age.secrets.ts-client-id.path}"
              "TS_CLIENT_SECRET_FILE=${config.age.secrets.ts-client-secret.path}"
              "TAILNET_ORG=${cfg.tailnetOrg}"
              "NODE_NAME=${toString cfg.hostName}"
            ];
          };
        };

    # Add systemd service to disable key expiry after connection
    systemd.services.tailscale-disable-key-expiry =
      mkIf
        (
          cfg.disableKeyExpiry
          && cfg.clientIdFile != null
          && cfg.clientSecretFile != null
          && cfg.tailnetOrg != null
          && cfg.hostName != null
        )
        {
          description = "Disable Tailscale key expiry";
          after = [ "tailscaled-autoconnect.service" ];
          wants = [ "tailscaled-autoconnect.service" ];
          wantedBy = [ "multi-user.target" ];
          path = [
            pkgs.bash
            pkgs.tailscale
            pkgs.jq
            pkgs.curl
          ];
          script = disableKeyExpiryScript;

          serviceConfig = {
            Type = "oneshot";
            Environment = [
              "TS_CLIENT_ID_FILE=${config.age.secrets.ts-client-id.path}"
              "TS_CLIENT_SECRET_FILE=${config.age.secrets.ts-client-secret.path}"
              "TAILNET_ORG=${cfg.tailnetOrg}"
              "NODE_NAME=${toString cfg.hostName}"
            ];
          };
        };

    # nixos/tailscale: tailscaled-autoconnect.service prevents multi-user.target from reaching "active" state when server errors #430756
    # https://github.com/NixOS/nixpkgs/issues/430756
    # Keep upstream Type=notify (script uses systemd-notify --ready) but add 30s timeout
    # so it can't block multi-user.target indefinitely if tailscale never connects
    systemd.services.tailscaled-autoconnect.serviceConfig.TimeoutStartSec = "30s";

  };
}
