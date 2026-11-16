# Tests for nixosModules.disk-alert (agnosticModules/disk-alert.nix): a
# oneshot service on a timer, configured through its environment; on Darwin
# enabling it fails an assertion instead of doing nothing.
{ self, ... }:
{
  perSystem =
    { lib, ... }:
    let
      t = self.neusis.lib.tests;

      nixosWith =
        extra:
        t.evalNixos {
          modules = [
            self.nixosModules.disk-alert
            {
              networking.hostName = "fixture";
              neusis.services.disk-alert = {
                enable = true;
              }
              // extra;
            }
          ];
        };

      nixos = nixosWith {
        mounts = {
          "/" = 85;
          "/boot" = 60;
        };
        notify = {
          environmentFile = "/run/agenix/notify";
          emailFrom = "bot@example.org";
          emailTo = [
            "a@example.org"
            "b@example.org"
          ];
        };
      };
      unit = nixos.systemd.services.neusis-disk-alert;
    in
    {
      tests.disk-alert = {
        test-checks-every-mount-on-a-timer = {
          expr = {
            inherit (unit.environment)
              DISK_ALERT_MOUNTS
              DISK_ALERT_HOST
              DISK_ALERT_ENV
              NTFY_URL
              ALERT_FROM
              ALERT_TO
              ;
            type = unit.serviceConfig.Type;
            exec = lib.hasSuffix "/bin/neusis-disk-alert" unit.serviceConfig.ExecStart;
            state = unit.serviceConfig.StateDirectory;
            timer = nixos.systemd.timers.neusis-disk-alert.timerConfig;
            timerWantedBy = nixos.systemd.timers.neusis-disk-alert.wantedBy;
            failed = t.failedAssertions nixos;
          };
          expected = {
            DISK_ALERT_MOUNTS = "/=85 /boot=60";
            DISK_ALERT_HOST = "fixture";
            DISK_ALERT_ENV = "/run/agenix/notify";
            NTFY_URL = "https://ntfy.sh";
            ALERT_FROM = "bot@example.org";
            ALERT_TO = "a@example.org,b@example.org";
            type = "oneshot";
            exec = true;
            state = "neusis-disk-alert";
            timer = {
              OnBootSec = "5min";
              OnUnitActiveSec = "15min";
            };
            timerWantedBy = [ "timers.target" ];
            failed = [ ];
          };
        };

        # Without credentials it only logs: no DISK_ALERT_ENV for the script to use.
        test-defaults-watch-root-and-only-log = {
          expr =
            let
              env = (nixosWith { }).systemd.services.neusis-disk-alert.environment;
            in
            {
              mounts = env.DISK_ALERT_MOUNTS;
              credentials = env ? DISK_ALERT_ENV;
            };
          expected = {
            mounts = "/=85";
            credentials = false;
          };
        };

        test-disabled-defines-no-unit = {
          expr =
            let
              off = t.evalNixos { modules = [ self.nixosModules.disk-alert ]; };
            in
            {
              service = off.systemd.services ? neusis-disk-alert;
              timer = off.systemd.timers ? neusis-disk-alert;
            };
          expected = {
            service = false;
            timer = false;
          };
        };

        test-darwin-fails-an-assertion = {
          expr = t.failedAssertions (
            t.evalDarwin {
              modules = [
                self.darwinModules.disk-alert
                { neusis.services.disk-alert.enable = true; }
              ];
            }
          );
          expected = [ "neusis.services.disk-alert is NixOS only (it runs a systemd timer)." ];
        };
      };
    };
}
