# Tests for {nixos,darwin}Modules.auto-update (agnosticModules/auto-update.nix):
# the options become one comin remote on the right branch, signed heads
# only, the deploy hook installed, and comin's binary from its own flake.
# On Darwin a check also builds the hook with its Homebrew branch (so
# shellcheck sees it); the Linux hook is built and run by vm-auto-update.
{ self, inputs, ... }:
{
  perSystem =
    { lib, pkgs, ... }:
    let
      t = self.neusis.lib.tests;

      settings = {
        enable = true;
        url = "https://example.com/repo.git";
        branch = "deploy/canary";
        pollPeriod = 30;
        signers = [
          {
            principal = "alice@example.com";
            key = "ssh-ed25519 AAAA1";
          }
        ];
      };

      nixos =
        extra:
        t.evalNixos {
          modules = [
            inputs.comin.nixosModules.comin
            self.nixosModules.auto-update
            {
              networking.hostName = "fixture";
              neusis.services.auto-update = settings;
            }
            extra
          ];
        };

      darwin =
        extra:
        t.evalDarwin {
          modules = [
            inputs.comin.darwinModules.comin
            self.darwinModules.auto-update
            {
              networking.hostName = "fixture-darwin";
              neusis.services.auto-update = settings;
            }
            extra
          ];
        };

      summary = cfg: {
        inherit (cfg.services.comin) enable;
        remotes = map (r: {
          inherit (r) name url;
          branch = r.branches.main.name;
          operation = r.branches.main.operation;
          period = r.poller.period;
        }) cfg.services.comin.remotes;
        signersChecked = cfg.services.comin.sshAllowedSignersPath != null;
        hook = lib.hasSuffix "/bin/neusis-auto-update-hook" cfg.services.comin.postDeploymentCommand;
        version = lib.getVersion cfg.services.comin.package;
        warnings = cfg.warnings;
        failed = t.failedAssertions cfg;
      };

      expected = {
        enable = true;
        remotes = [
          {
            name = "origin";
            url = "https://example.com/repo.git";
            branch = "deploy/canary";
            operation = "switch";
            period = 30;
          }
        ];
        signersChecked = true;
        hook = true;
        version = "0.14.0";
        warnings = [ ];
        failed = [ ];
      };
    in
    {
      checks = lib.optionalAttrs pkgs.stdenv.isDarwin {
        auto-update-hook-darwin =
          let
            cfg = darwin {
              homebrew.enable = true;
              neusis.services.auto-update.notify = {
                environmentFile = "/run/agenix/autoUpdateNotify";
                emailFrom = "bot@example.com";
                emailTo = [ "alice@example.com" ];
              };
            };
          in
          pkgs.runCommand "auto-update-hook-darwin" { } ''
            test -x ${cfg.services.comin.postDeploymentCommand}
            touch $out
          '';
      };

      tests.agnostic-auto-update = {
        test-nixos-comin-follows-the-branch = {
          expr = summary (nixos { }) // {
            unit = (nixos { }).systemd.services ? comin;
          };
          expected = expected // {
            unit = true;
          };
        };

        test-darwin-comin-follows-the-branch = {
          expr = summary (darwin { }) // {
            daemon = (darwin { }).launchd.daemons ? comin;
          };
          expected = expected // {
            daemon = true;
          };
        };

        # The hook's Homebrew delta reads `homebrew.brewPrefix` and the
        # primary user; instantiating it proves those resolve.
        test-darwin-hook-with-homebrew = {
          expr =
            (summary (darwin {
              homebrew.enable = true;
            })).hook;
          expected = true;
        };

        test-notifications-instantiate = {
          expr =
            (summary (nixos {
              neusis.services.auto-update.notify = {
                environmentFile = "/run/agenix/autoUpdateNotify";
                emailFrom = "bot@example.com";
                emailTo = [ "alice@example.com" ];
              };
            })).hook;
          expected = true;
        };

        test-no-signers-warns-and-skips-the-check = {
          expr =
            let
              cfg = nixos { neusis.services.auto-update.signers = lib.mkForce [ ]; };
            in
            {
              signersChecked = cfg.services.comin.sshAllowedSignersPath != null;
              warned = lib.length cfg.warnings;
            };
          expected = {
            signersChecked = false;
            warned = 1;
          };
        };

        test-disabled-leaves-comin-off = {
          expr = (nixos { neusis.services.auto-update.enable = lib.mkForce false; }).services.comin.enable;
          expected = false;
        };
      };
    };
}
