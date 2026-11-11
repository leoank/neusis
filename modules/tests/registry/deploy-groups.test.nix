# Pins anklab's deploy groups (modules/registry/deploy-groups/anklab.nix):
# canary (rogue) leads, stable (ghost001) trails it by a day, and every
# member is a machine the lab actually builds.
{ self, ... }:
{
  perSystem =
    { lib, ... }:
    let
      groups = self.neusis.registry.deployGroups.anklab;
      built = map (m: m.hostname) (
        self.neusis.registry.machines.anklab.nixos ++ self.neusis.registry.machines.anklab.darwin
      );
    in
    {
      tests.registry-deploy-groups = {
        test-anklab-groups = {
          expr = lib.mapAttrs (_: g: {
            inherit (g)
              branch
              after
              soakHours
              pollPeriod
              ci
              ;
            machines = map (m: m.hostname) g.machines;
          }) groups;
          expected = {
            canary = {
              branch = "deploy/canary";
              after = null;
              soakHours = 0;
              pollPeriod = 60;
              ci = true;
              machines = [ "rogue" ];
            };
            stable = {
              branch = "deploy/stable";
              after = "canary";
              soakHours = 24;
              pollPeriod = 60;
              ci = true;
              machines = [ "ghost001" ];
            };
            # curiosity alone and out of CI, so CI never builds its kernel and it never holds
            # back canary or stable
            live = {
              branch = "deploy/live";
              after = null;
              soakHours = 0;
              pollPeriod = 60;
              ci = false;
              machines = [ "curiosity" ];
            };
          };
        };

        test-anklab-groups-pass-the-checks = {
          expr = self.neusis.lib.autoUpdate.checkGroups groups;
          expected = [ ];
        };

        # What gates.yml builds before promoting each group: not curiosity (live, ci = false).
        test-anklab-ci-matrix = {
          expr = self.neusis.lib.autoUpdate.ciMatrix {
            inherit groups;
            inherit (self) checks;
          };
          expected = [
            {
              host = "rogue";
              group = "canary";
              system = "aarch64-darwin";
              checks = [
                "darwin-rogue"
                "home-ank@rogue"
              ];
            }
            {
              host = "ghost001";
              group = "stable";
              system = "aarch64-linux";
              checks = [
                "home-ank@ghost001"
                "nixos-ghost001"
              ];
            }
          ];
        };

        # CI evaluates and builds nothing of curiosity's: no system, home or ISO check on any
        # system (T1 instantiates every check; the ISO is in legacyPackages, not packages).
        test-curiosity-has-no-checks = {
          expr = lib.concatMap (
            sys: lib.filter (n: lib.hasInfix "curiosity" n) (lib.attrNames self.checks.${sys})
          ) (lib.attrNames self.checks);
          expected = [ ];
        };

        test-every-member-is-built-by-the-lab = {
          expr = lib.filter (h: !(lib.elem h built)) (
            lib.concatMap (g: map (m: m.hostname) g.machines) (lib.attrValues groups)
          );
          expected = [ ];
        };
      };
    };
}
