# Tests for nixosModules.cloudflare-tunnel (agnosticModules/cloudflare-tunnel.nix):
# a hardened cloudflared unit fed the token as a systemd credential; on
# Darwin enabling it fails an assertion instead of doing nothing.
{ self, ... }:
{
  perSystem =
    { lib, ... }:
    let
      t = self.neusis.lib.tests;

      nixos = t.evalNixos {
        modules = [
          self.nixosModules.cloudflare-tunnel
          {
            neusis.services.cloudflare-tunnel = {
              enable = true;
              tokenFile = "/run/agenix/cfTunnelToken";
            };
          }
        ];
      };
      off = t.evalNixos { modules = [ self.nixosModules.cloudflare-tunnel ]; };
      darwin = t.evalDarwin {
        modules = [
          self.darwinModules.cloudflare-tunnel
          {
            neusis.services.cloudflare-tunnel = {
              enable = true;
              tokenFile = "/run/agenix/cfTunnelToken";
            };
          }
        ];
      };

      unit = nixos.systemd.services.cloudflared-tunnel;
    in
    {
      tests.cloudflare-tunnel = {
        test-connector-runs-with-the-token-as-a-credential = {
          expr = {
            exec = lib.hasSuffix "/bin/cloudflared tunnel --no-autoupdate run --token-file %d/token" unit.serviceConfig.ExecStart;
            credential = unit.serviceConfig.LoadCredential;
            dynamicUser = unit.serviceConfig.DynamicUser;
            restart = unit.serviceConfig.Restart;
            wantedBy = unit.wantedBy;
            afterNetwork = builtins.elem "network-online.target" unit.after;
            failed = t.failedAssertions nixos;
          };
          expected = {
            exec = true;
            credential = [ "token:/run/agenix/cfTunnelToken" ];
            dynamicUser = true;
            restart = "on-failure";
            wantedBy = [ "multi-user.target" ];
            afterNetwork = true;
            failed = [ ];
          };
        };

        test-disabled-defines-no-unit = {
          expr = off.systemd.services ? cloudflared-tunnel;
          expected = false;
        };

        test-darwin-refuses-to-enable = {
          expr = map (m: lib.hasInfix "NixOS only" m) (t.failedAssertions darwin);
          expected = [ true ];
        };
      };
    };
}
