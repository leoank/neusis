# Tests for flake.neusis.features.nixos.rc2s2-hub: it turns on the hub
# with the data volume and the local ntfy, and points the token flags at
# the agenix secret paths. agenix is stubbed (the real machine test
# exercises it with agenix present).
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
      # Minimal stand-in for agenix: enough that `age.secrets.<n>.path`
      # resolves to /run/agenix/<n> while the feature sets rekeyFile/owner.
      stubAgenix =
        { lib, ... }:
        {
          options.age.secrets = lib.mkOption {
            default = { };
            type = lib.types.attrsOf (
              lib.types.submodule (
                { name, ... }:
                {
                  options = {
                    rekeyFile = lib.mkOption { type = lib.types.path; };
                    owner = lib.mkOption {
                      type = lib.types.str;
                      default = "root";
                    };
                    group = lib.mkOption {
                      type = lib.types.str;
                      default = "root";
                    };
                    path = lib.mkOption {
                      type = lib.types.str;
                      default = "/run/agenix/${name}";
                    };
                  };
                }
              )
            );
          };
        };
      cfg = t.evalNixos {
        system = "aarch64-linux";
        modules = [
          stubAgenix
          self.nixosModules.rc2s2-hub
          self.neusis.features.nixos.rc2s2-hub
          { neusis.services.rc2s2-hub.package = fakePkg; }
        ];
      };
      e = cfg.systemd.services.rc2s2-hub.serviceConfig.ExecStart;
    in
    {
      tests.feature-nixos-rc2s2-hub = {
        test-wires-hub-and-ntfy = {
          expr = {
            hubOn = cfg.neusis.services.rc2s2-hub.enable;
            dataDir = cfg.neusis.services.rc2s2-hub.dataDir;
            db = lib.hasInfix "--db /srv/rc2s2/hub.db" e;
            nodeTokens = lib.hasInfix "--node-tokens /run/agenix/rc2s2NodeTokens" e;
            clientTokens = lib.hasInfix "--client-tokens /run/agenix/rc2s2ClientTokens" e;
            ntfyFlag = lib.hasInfix "--ntfy http://127.0.0.1:2586/rc2s2" e;
            secretOwner = cfg.age.secrets.rc2s2NodeTokens.owner;
            ntfyOn = cfg.services.ntfy-sh.enable;
            ntfyListen = cfg.services.ntfy-sh.settings.listen-http;
            ntfyBaseUrl = cfg.services.ntfy-sh.settings.base-url;
            firewallClosed = (cfg.networking.firewall.allowedTCPPorts or [ ]) == [ ];
          };
          expected = {
            hubOn = true;
            dataDir = "/srv/rc2s2";
            db = true;
            nodeTokens = true;
            clientTokens = true;
            ntfyFlag = true;
            secretOwner = "rc2s2-hub";
            ntfyOn = true;
            ntfyListen = ":2586";
            ntfyBaseUrl = "http://ghost001:2586";
            firewallClosed = true;
          };
        };
      };
    };
}
