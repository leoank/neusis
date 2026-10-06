# Tests for flake.agnosticModules.tailscale on both platforms. Guards the
# `options ? launchd` / `options ? systemd` dispatch: each platform gets
# its own autoconnect unit and never sees the other's option tree.
{ self, ... }:
{
  perSystem =
    { lib, ... }:
    let
      t = self.neusis.lib.tests;

      profiles = {
        leoank = {
          authKeyFile = "/run/agenix/tsAuthKeyLeoank";
          hostName = "fixture";
          extraUpFlags = [ "--ssh" ];
        };
        cslab = {
          authKeyFile = "/run/agenix/tsAuthKeyCslab";
        };
      };

      enabled = {
        neusis.services.tailscale = {
          enable = true;
          defaultProfile = "leoank";
          inherit profiles;
        };
      };

      darwin = t.evalDarwin {
        modules = [
          self.darwinModules.tailscale
          enabled
          { neusis.services.tailscale.overrideLocalDns = true; }
        ];
      };

      nixos = t.evalNixos {
        modules = [
          self.nixosModules.tailscale
          enabled
          {
            neusis.services.tailscale.openFirewall = false;
            neusis.services.tailscale.useRoutingFeatures = "both";
          }
        ];
      };

      darwinNoAuto = t.evalDarwin {
        modules = [
          self.darwinModules.tailscale
          enabled
          { neusis.services.tailscale.autoConnect = false; }
        ];
      };

      nixosNoAuto = t.evalNixos {
        modules = [
          self.nixosModules.tailscale
          enabled
          { neusis.services.tailscale.autoConnect = false; }
        ];
      };

      disabled = t.evalDarwin {
        modules = [
          self.darwinModules.tailscale
          { neusis.services.tailscale.defaultProfile = "leoank"; }
        ];
      };

      badDefault = t.evalNixos {
        modules = [
          self.nixosModules.tailscale
          {
            neusis.services.tailscale = {
              enable = true;
              defaultProfile = "missing";
              inherit profiles;
            };
          }
        ];
      };

      # Per-profile switch scripts land on PATH as `neusis-ts-<name>`.
      scriptNames = cfg: lib.filter (lib.hasPrefix "neusis-ts-") (t.pkgNames cfg.environment.systemPackages);
    in
    {
      tests.agnostic-tailscale = {
        test-darwin-enables-daemon-and-launchd-autoconnect = {
          expr = {
            service = darwin.services.tailscale.enable;
            overrideLocalDns = darwin.services.tailscale.overrideLocalDns;
            label = darwin.launchd.daemons.neusis-tailscale-autoconnect.serviceConfig.Label;
            retryUntilSuccess = darwin.launchd.daemons.neusis-tailscale-autoconnect.serviceConfig.KeepAlive.SuccessfulExit;
            runAtLoad = darwin.launchd.daemons.neusis-tailscale-autoconnect.serviceConfig.RunAtLoad;
            noSystemd = !(darwin ? systemd);
            cli = t.hasPkg "tailscale" darwin.environment.systemPackages;
            scripts = scriptNames darwin;
            failed = t.failedAssertions darwin;
          };
          expected = {
            service = true;
            overrideLocalDns = true;
            label = "org.neusis.tailscale-autoconnect";
            retryUntilSuccess = false;
            runAtLoad = true;
            noSystemd = true;
            cli = true;
            scripts = [
              "neusis-ts-cslab"
              "neusis-ts-leoank"
            ];
            failed = [ ];
          };
        };

        test-nixos-enables-daemon-and-systemd-autoconnect = {
          expr =
            let
              unit = nixos.systemd.services.neusis-tailscale-autoconnect;
            in
            {
              service = nixos.services.tailscale.enable;
              openFirewall = nixos.services.tailscale.openFirewall;
              routing = nixos.services.tailscale.useRoutingFeatures;
              type = unit.serviceConfig.Type;
              remain = unit.serviceConfig.RemainAfterExit;
              afterTailscaled = builtins.elem "tailscaled.service" unit.after;
              wantedBy = unit.wantedBy;
              noLaunchd = !(nixos ? launchd);
              scripts = scriptNames nixos;
              failed = t.failedAssertions nixos;
            };
          expected = {
            service = true;
            openFirewall = false;
            routing = "both";
            type = "oneshot";
            remain = true;
            afterTailscaled = true;
            wantedBy = [ "multi-user.target" ];
            noLaunchd = true;
            scripts = [
              "neusis-ts-cslab"
              "neusis-ts-leoank"
            ];
            failed = [ ];
          };
        };

        test-autoconnect-off-defines-no-unit = {
          expr = {
            darwin = darwinNoAuto.launchd.daemons ? neusis-tailscale-autoconnect;
            nixos = nixosNoAuto.systemd.services ? neusis-tailscale-autoconnect;
            stillHasScripts = scriptNames darwinNoAuto;
          };
          expected = {
            darwin = false;
            nixos = false;
            stillHasScripts = [
              "neusis-ts-cslab"
              "neusis-ts-leoank"
            ];
          };
        };

        test-disabled-leaves-system-untouched = {
          expr = {
            service = disabled.services.tailscale.enable;
            daemon = disabled.launchd.daemons ? neusis-tailscale-autoconnect;
            cli = t.hasPkg "tailscale" disabled.environment.systemPackages;
          };
          expected = {
            service = false;
            daemon = false;
            cli = false;
          };
        };

        test-default-profile-must-exist = {
          expr = t.failedAssertions badDefault;
          expected = [
            "neusis.services.tailscale.defaultProfile 'missing' is not defined in profiles."
          ];
        };

        test-profile-option-defaults = {
          expr = {
            inherit (darwin.neusis.services.tailscale.profiles.cslab)
              hostName
              extraUpFlags
              ephemeral
              forceHostName
              disableKeyExpiry
              tailnetOrg
              ;
          };
          expected = {
            hostName = null;
            extraUpFlags = [ ];
            ephemeral = false;
            forceHostName = false;
            disableKeyExpiry = false;
            tailnetOrg = null;
          };
        };
      };
    };
}
