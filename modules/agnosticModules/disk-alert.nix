# Disk-usage alerts: a timer checks how full each listed mount is and, past its
# threshold, sends one alert through neusis-notify (ntfy and email, the same
# credentials auto-update uses). It alerts again after a day if the mount stays
# full, and forgets once it drops below the threshold.
#
# NixOS only (systemd). Lives in agnosticModules so it is re-exported as
# `nixosModules.disk-alert`; enabling it on Darwin fails an assertion rather
# than silently doing nothing.
{ self, ... }:
{
  flake.agnosticModules.disk-alert =
    {
      config,
      options,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.neusis.services.disk-alert;
      isLinux = options ? systemd;

      check = pkgs.writeShellApplication {
        name = "neusis-disk-alert";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gawk
          pkgs.findutils
          self.packages.${pkgs.stdenv.hostPlatform.system}.neusis-notify
        ];
        text = ''
          state=''${STATE_DIRECTORY:-/var/lib/neusis-disk-alert}
          mkdir -p "$state"
          # DISK_ALERT_MOUNTS: "<mount>=<max percent> …"
          for spec in $DISK_ALERT_MOUNTS; do
            mount=''${spec%=*}
            max=''${spec##*=}
            used=$(df -P "$mount" | awk 'NR == 2 { sub("%", "", $5); print $5 }') || continue
            stamp="$state/$(printf %s "$mount" | tr / _)"
            if [ "$used" -lt "$max" ]; then
              rm -f "$stamp"
              continue
            fi
            # once a day while it stays full
            if [ -e "$stamp" ] && [ -z "$(find "$stamp" -mmin +1440)" ]; then
              continue
            fi
            message="$mount is $used% full (alert at $max%)"
            echo "$message" >&2
            if [ -n "''${DISK_ALERT_ENV:-}" ]; then
              neusis-notify --env-file "$DISK_ALERT_ENV" --title "$DISK_ALERT_HOST: disk" \
                --priority high --tags warning "$message" && touch "$stamp"
            else
              touch "$stamp"
            fi
          done
        '';
      };
    in
    {
      options.neusis.services.disk-alert = {
        enable = lib.mkEnableOption "alerts when a mount fills past a threshold";

        mounts = lib.mkOption {
          type = lib.types.attrsOf (lib.types.ints.between 1 100);
          default = {
            "/" = 85;
          };
          example = {
            "/" = 85;
            "/boot" = 60;
          };
          description = "Mount points to watch and the percentage used at which each alerts.";
        };

        interval = lib.mkOption {
          type = lib.types.str;
          default = "15min";
          description = "How often to check, as a systemd time span.";
        };

        notify = {
          environmentFile = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "/run/agenix/autoUpdateNotify";
            description = ''
              Dotenv file with the neusis-notify credentials (`NTFY_TOPIC`,
              optional `NTFY_TOKEN`, `POSTMARK_API_KEY`), typically an agenix
              secret. `null` only logs to the journal.
            '';
          };
          ntfyUrl = lib.mkOption {
            type = lib.types.str;
            default = "https://ntfy.sh";
            description = "ntfy server.";
          };
          emailFrom = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Sender address (a confirmed Postmark sender). `null` sends no email.";
          };
          emailTo = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Recipients of alert emails.";
          };
        };
      };

      config = lib.mkIf cfg.enable (
        {
          assertions = [
            {
              assertion = isLinux;
              message = "neusis.services.disk-alert is NixOS only (it runs a systemd timer).";
            }
          ];
        }
        // lib.optionalAttrs isLinux {
          systemd.services.neusis-disk-alert = {
            description = "Alert when a watched mount is nearly full";
            environment = {
              DISK_ALERT_MOUNTS = lib.concatStringsSep " " (lib.mapAttrsToList (m: max: "${m}=${toString max}") cfg.mounts);
              DISK_ALERT_HOST = config.networking.hostName;
              NTFY_URL = cfg.notify.ntfyUrl;
              ALERT_FROM = toString cfg.notify.emailFrom;
              ALERT_TO = lib.concatStringsSep "," cfg.notify.emailTo;
            }
            // lib.optionalAttrs (cfg.notify.environmentFile != null) {
              DISK_ALERT_ENV = cfg.notify.environmentFile;
            };
            serviceConfig = {
              Type = "oneshot";
              ExecStart = lib.getExe check;
              StateDirectory = "neusis-disk-alert";
            };
          };
          systemd.timers.neusis-disk-alert = {
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnBootSec = "5min";
              OnUnitActiveSec = cfg.interval;
            };
          };
        }
      );
    };
}
