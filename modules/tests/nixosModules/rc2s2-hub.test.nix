# Tests for flake.nixosModules.rc2s2-hub: the hub systemd service, its
# user and data directory, the token flags, and optional ntfy/firewall.
{ self, ... }:
{
  perSystem =
    {
      lib,
      testPkgs,
      ...
    }:
    let
      t = self.neusis.lib.tests;
      fakePkg = testPkgs.writeShellScriptBin "rc2s2-hub" "exit 0";
      hub =
        extra:
        t.evalNixos {
          modules = [
            self.nixosModules.rc2s2-hub
            {
              neusis.services.rc2s2-hub = {
                enable = true;
                package = fakePkg;
                nodeTokensFile = "/run/agenix/n";
                clientTokensFile = "/run/agenix/c";
              }
              // extra;
            }
          ];
        };
      base = hub { };
      exec = cfg: cfg.systemd.services.rc2s2-hub.serviceConfig.ExecStart;
    in
    {
      tests.nixos-rc2s2-hub = {
        test-service-defaults = {
          expr =
            let
              s = base.systemd.services.rc2s2-hub;
              e = exec base;
            in
            {
              wantedBy = s.wantedBy;
              user = s.serviceConfig.User;
              restart = s.serviceConfig.Restart;
              db = lib.hasInfix "--db /var/lib/rc2s2-hub/hub.db" e;
              nodeTokens = lib.hasInfix "--node-tokens /run/agenix/n" e;
              clientTokens = lib.hasInfix "--client-tokens /run/agenix/c" e;
              noNtfyByDefault = !(lib.hasInfix "--ntfy" e);
              userIsSystem = base.users.users.rc2s2-hub.isSystemUser;
              rwDataDir = builtins.elem "/var/lib/rc2s2-hub" s.serviceConfig.ReadWritePaths;
              firewallClosedByDefault = (base.networking.firewall.allowedTCPPorts or [ ]) == [ ];
              failed = t.failedAssertions base;
            };
          expected = {
            wantedBy = [ "multi-user.target" ];
            user = "rc2s2-hub";
            restart = "on-failure";
            db = true;
            nodeTokens = true;
            clientTokens = true;
            noNtfyByDefault = true;
            userIsSystem = true;
            rwDataDir = true;
            firewallClosedByDefault = true;
            failed = [ ];
          };
        };

        test-ntfy-datadir-and-firewall = {
          expr =
            let
              s = hub {
                ntfy = "http://127.0.0.1:2586/rc2s2";
                dataDir = "/srv/rc2s2";
                openFirewall = true;
                listen = "0.0.0.0:7700";
              };
              e = exec s;
            in
            {
              ntfy = lib.hasInfix "--ntfy http://127.0.0.1:2586/rc2s2" e;
              db = lib.hasInfix "--db /srv/rc2s2/hub.db" e;
              listen = lib.hasInfix "--listen 0.0.0.0:7700" e;
              port = builtins.elem 7700 s.networking.firewall.allowedTCPPorts;
            };
          expected = {
            ntfy = true;
            db = true;
            listen = true;
            port = true;
          };
        };
      };
    };
}
