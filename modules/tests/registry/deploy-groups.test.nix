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
              ;
            machines = map (m: m.hostname) g.machines;
          }) groups;
          expected = {
            canary = {
              branch = "deploy/canary";
              after = null;
              soakHours = 0;
              pollPeriod = 60;
              machines = [ "rogue" ];
            };
            stable = {
              branch = "deploy/stable";
              after = "canary";
              soakHours = 24;
              pollPeriod = 60;
              machines = [ "ghost001" ];
            };
          };
        };

        test-anklab-groups-pass-the-checks = {
          expr = self.neusis.lib.autoUpdate.checkGroups groups;
          expected = [ ];
        };

        # What gates.yml builds before promoting each group.
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

        test-every-member-is-built-by-the-lab = {
          expr = lib.filter (h: !(lib.elem h built)) (
            lib.concatMap (g: map (m: m.hostname) g.machines) (lib.attrValues groups)
          );
          expected = [ ];
        };
      };
    };
}
