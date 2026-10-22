# Tests for flake.neusis.lib.autoUpdate (modules/lib/auto-update.nix):
# the deploy-group checks, group lookup and the allowed_signers render.
{ self, ... }:
{
  perSystem =
    { ... }:
    let
      au = self.neusis.lib.autoUpdate;

      # A group as the option type would complete it.
      group =
        hosts: extra:
        {
          machines = map (h: { hostname = h; }) hosts;
          after = null;
          soakHours = 0;
          pollPeriod = 60;
        }
        // extra;

      valid = {
        canary = group [ "a" ] { };
        stable = group [
          "b"
          "c"
        ] {
          after = "canary";
          soakHours = 24;
        };
      };
    in
    {
      tests.lib-auto-update = {
        test-valid-groups-have-no-problems = {
          expr = au.checkGroups valid;
          expected = [ ];
        };

        test-empty-groups-are-valid = {
          expr = au.checkGroups { };
          expected = [ ];
        };

        test-group-names-must-be-ref-safe = {
          expr = au.checkGroups {
            Canary = group [ ] { };
            "with/slash" = group [ ] { };
            ok-1 = group [ ] { };
          };
          expected = [
            "deploy group `Canary`: name must match [a-z0-9][a-z0-9-]*"
            "deploy group `with/slash`: name must match [a-z0-9][a-z0-9-]*"
          ];
        };

        test-a-machine-in-two-groups-is-rejected = {
          expr = au.checkGroups {
            one = group [ "a" ] { };
            two = group [
              "a"
              "b"
            ] { };
          };
          expected = [ "machine `a` is in more than one deploy group: one, two" ];
        };

        test-after-must-name-a-group = {
          expr = au.checkGroups { stable = group [ ] { after = "canary"; }; };
          expected = [ "deploy group `stable`: `after` names unknown group `canary`" ];
        };

        test-after-loops-are-rejected = {
          expr = au.checkGroups {
            a = group [ ] { after = "b"; };
            b = group [ ] { after = "a"; };
            self-loop = group [ ] { after = "self-loop"; };
          };
          expected = [
            "deploy group `a`: `after` chain loops back to itself"
            "deploy group `b`: `after` chain loops back to itself"
            "deploy group `self-loop`: `after` chain loops back to itself"
          ];
        };

        test-soak-needs-after = {
          expr = au.checkGroups { canary = group [ ] { soakHours = 6; }; };
          expected = [ "deploy group `canary`: `soakHours` needs `after`" ];
        };

        test-group-of-a-host = {
          expr = {
            a = au.groupOf valid "a";
            c = au.groupOf valid "c";
            none = au.groupOf valid "nobody";
          };
          expected = {
            a = "canary";
            c = "stable";
            none = null;
          };
        };

        test-allowed-signers-render = {
          expr = au.allowedSigners [
            {
              principal = "alice@example.com";
              key = "ssh-ed25519 AAAA1";
            }
            {
              principal = "bot@example.com";
              key = "ssh-ed25519 AAAA2";
            }
          ];
          expected = ''
            alice@example.com namespaces="git" ssh-ed25519 AAAA1
            bot@example.com namespaces="git" ssh-ed25519 AAAA2
          '';
        };
      };
    };
}
