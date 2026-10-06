# CSLab Monitoring Module
#
# Implements monitoring policies for CSLab servers:
# - Weekly quota checks (configurable schedule)
# - Weekly group membership checks
# - Slack webhook notifications
#
# References:
# - imaging-server-maintenance/policies/data-storage.md (quota monitoring)
# - imaging-server-maintenance/policies/user-access.md (group membership)
#
# Extracted from machines/oppy/cslab/monitoring.nix.
#
# Usage:
#   neusis.cslab.monitoring = {
#     enable = true;
#     userConfigPath = ../../users/cslab.nix;
#     machineName = "Oppy";
#     slackWebhookSecretFile = ../../secrets/oppy/slack_webhook.age;
#     quotaCheckScript = ./cslab/scripts/check-quotas.nu;
#   };

{ config, lib, pkgs, ... }:

let
  cfg = config.neusis.cslab.monitoring;

  # Import cslab user config to derive expected group memberships
  cslabUserConfig = import cfg.userConfigPath { inherit pkgs; };

  # Extract usernames by type
  adminUsernames = builtins.map (u: u.username) cslabUserConfig.admins;
  regularUsernames = builtins.map (u: u.username) cslabUserConfig.regulars;

  # Generate group violation check script
  checkGroupsScript = pkgs.writeShellScript "check-groups.sh" ''
    LOG_FILE=/var/log/lab-scripts/group-violations.log
    mkdir -p /var/log/lab-scripts

    VIOLATIONS=""
    TIMESTAMP=$(date -Iseconds)

    # Check regulars don't have wheel group (unauthorized sudo)
    REGULARS="${lib.concatStringsSep " " regularUsernames}"
    for user in $REGULARS; do
      if groups "$user" | grep -qw wheel; then
        VIOLATIONS="$VIOLATIONS- $user has wheel group (unauthorized sudo)\n"
      fi
    done

    # Check admins DO have wheel group (expected sudo)
    ADMINS="${lib.concatStringsSep " " adminUsernames}"
    for user in $ADMINS; do
      if ! groups "$user" | grep -qw wheel; then
        VIOLATIONS="$VIOLATIONS- $user missing wheel group (admin should have sudo)\n"
      fi
    done

    # Report violations if found
    if [ -n "$VIOLATIONS" ]; then
      echo "[$TIMESTAMP] Group violations detected" >> "$LOG_FILE"
      echo -e "$VIOLATIONS" >> "$LOG_FILE"

      # Send Slack notification
      if [ -n "$SLACK_WEBHOOK_URL" ]; then
        curl -X POST -H 'Content-type: application/json' \
          --data "{\"text\":\"🚨 Security Alert: Group membership violations detected on ${cfg.machineName}\n\n$VIOLATIONS\nRun \`nixos-rebuild switch\` to enforce correct groups.\"}" \
          "$SLACK_WEBHOOK_URL" 2>&1 | tee -a "$LOG_FILE"
      fi

      exit 2  # Exit code 2 = violations found
    else
      echo "[$TIMESTAMP] No group violations detected" >> "$LOG_FILE"
      exit 0
    fi
  '';

in
{
  options.neusis.cslab.monitoring = {
    enable = lib.mkEnableOption "CSLab monitoring (quota checks, group audits, Slack alerts)";

    userConfigPath = lib.mkOption {
      type = lib.types.path;
      description = "Path to the users/*.nix config file for this machine's CSLab users";
    };

    machineName = lib.mkOption {
      type = lib.types.str;
      default = config.networking.hostName;
      description = "Machine name used in Slack alert messages (defaults to hostname)";
    };

    slackWebhookSecretFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to the age-encrypted Slack webhook secret file";
      example = "../../secrets/oppy/slack_webhook.age";
    };

    quotaCheckScript = lib.mkOption {
      type = lib.types.path;
      description = "Path to the check-quotas.nu nushell script";
    };

    quotaLimit = lib.mkOption {
      type = lib.types.ints.positive;
      default = 100;
      description = "Quota limit in GB for home directory checks";
    };

    homeBaseDir = lib.mkOption {
      type = lib.types.str;
      default = "/home";
      description = "Base directory for user home directories (for quota checks)";
    };
  };

  config = lib.mkIf cfg.enable {
    # Slack webhook secret for quota notifications
    age.secrets.slack_webhook = {
      file = cfg.slackWebhookSecretFile;
      mode = "400";  # Read-only by root
      owner = "root";
    };

    # Weekly quota monitoring - Mondays at 9 AM
    systemd.timers.cslab-check-quotas = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "Mon *-*-* 09:00:00";  # Weekly on Monday morning
        Persistent = true;  # Run on boot if missed
        RandomizedDelaySec = "5m";  # Spread load if multiple servers
      };
    };

    systemd.services.cslab-check-quotas = {
      description = "CSLab Home Directory Quota Check";

      # Script requires fd for file search
      path = [ pkgs.fd ];

      serviceConfig = {
        Type = "oneshot";
        User = "root";  # Needs root to read all user directories

        # Environment variables for script configuration
        Environment = [
          "HOME_BASE_DIR=${cfg.homeBaseDir}"
          "QUOTA_GB=${toString cfg.quotaLimit}"
          "LARGE_FILE_GB=1"
          "LOG_DIR=/var/log/lab-scripts"
        ];

        # Script exits with code 2 when users need action (by design)
        # Treat this as success so systemd doesn't report failures
        SuccessExitStatus = [ 0 2 ];
      };

      script = ''
        # Create log directory
        mkdir -p /var/log/lab-scripts

        # Load Slack webhook URL from secret
        export SLACK_WEBHOOK_URL=$(cat ${config.age.secrets.slack_webhook.path})

        # Run quota check script with Slack notifications enabled
        ${pkgs.nushell}/bin/nu ${cfg.quotaCheckScript}
      '';
    };

    # Weekly group membership monitoring - Wednesdays at 9 AM
    systemd.timers.cslab-check-groups = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "Wed *-*-* 09:00:00";  # Weekly on Wednesday morning
        Persistent = true;  # Run on boot if missed
        RandomizedDelaySec = "5m";  # Spread load if multiple servers
      };
    };

    systemd.services.cslab-check-groups = {
      description = "CSLab Group Membership Violation Check";

      serviceConfig = {
        Type = "oneshot";
        User = "root";  # Needs root to check all users

        # Exit code 2 = violations found (by design)
        # Treat this as success so systemd doesn't report failures
        SuccessExitStatus = [ 0 2 ];
      };

      script = ''
        # Load Slack webhook URL from secret
        export SLACK_WEBHOOK_URL=$(cat ${config.age.secrets.slack_webhook.path})

        # Run group violation check script
        ${checkGroupsScript}
      '';
    };

    # Future: Scratch cleanup (90-day retention policy)
    # Uncomment when scratch-cleanup.nu script is ready
    #
    # systemd.timers.cslab-scratch-cleanup = {
    #   wantedBy = [ "timers.target" ];
    #   timerConfig = {
    #     OnCalendar = "daily";
    #     Persistent = true;
    #   };
    # };
    #
    # systemd.services.cslab-scratch-cleanup = {
    #   description = "CSLab Scratch Directory Cleanup (90-day retention)";
    #   serviceConfig = {
    #     Type = "oneshot";
    #     User = "root";
    #   };
    #   script = ''
    #     ${pkgs.nushell}/bin/nu /path/to/scratch-cleanup.nu
    #   '';
    # };
  };
}
