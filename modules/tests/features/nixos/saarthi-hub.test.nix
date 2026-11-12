# Tests for flake.neusis.features.nixos.saarthi-hub: it turns on the hub
# (the saarthi flake's module) with the data volume and the local ntfy,
# points the token flags at the agenix secret paths, and copies the
# record over from /srv/rc2s2 before the first start. agenix is stubbed
# (the real machine test exercises it with agenix present).
{ self, inputs, ... }:
{
  perSystem =
    {
      lib,
      testPkgs,
      ...
    }:
    let
      t = self.neusis.lib.tests;
      fakePkg = testPkgs.writeShellScriptBin "saarthi-hub" "exit 0";
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
          inputs.saarthi.nixosModules.saarthi-hub
          self.neusis.features.nixos.saarthi-hub
          { services.saarthi-hub.package = fakePkg; }
        ];
      };
      s = cfg.systemd.services.saarthi-hub.serviceConfig;
      e = s.ExecStart;
      pre = builtins.head s.ExecStartPre;
    in
    {
      tests.feature-nixos-saarthi-hub = {
        test-wires-hub-and-ntfy = {
          expr = {
            hubOn = cfg.services.saarthi-hub.enable;
            dataDir = cfg.services.saarthi-hub.dataDir;
            db = lib.hasInfix "--db /srv/saarthi/hub.db" e;
            nodeTokens = lib.hasInfix "--node-tokens /run/agenix/saarthiNodeTokens" e;
            clientTokens = lib.hasInfix "--client-tokens /run/agenix/saarthiClientTokens" e;
            claudeTokens = lib.hasInfix "--claude-tokens /run/agenix/saarthiClaudeTokens" e;
            usageProbe = lib.hasInfix "--usage-probe-node ghost001 --usage-probe-minutes 30" e;
            ntfyFlag = lib.hasInfix "--ntfy http://127.0.0.1:2586/saarthi" e;
            secretOwner = cfg.age.secrets.saarthiNodeTokens.owner;
            # the copy from /srv/rc2s2 runs as root before the hub starts
            # (the script is not read here: that would build it at eval)
            migrateAsRoot = builtins.match "[+]/nix/store/[a-z0-9]+-saarthi-hub-migrate" pre != null;
            ntfyOn = cfg.services.ntfy-sh.enable;
            ntfyListen = cfg.services.ntfy-sh.settings.listen-http;
            ntfyBaseUrl = cfg.services.ntfy-sh.settings.base-url;
            firewallClosed = (cfg.networking.firewall.allowedTCPPorts or [ ]) == [ ];
          };
          expected = {
            hubOn = true;
            dataDir = "/srv/saarthi";
            db = true;
            nodeTokens = true;
            clientTokens = true;
            claudeTokens = true;
            usageProbe = true;
            ntfyFlag = true;
            secretOwner = "saarthi-hub";
            migrateAsRoot = true;
            ntfyOn = true;
            ntfyListen = ":2586";
            ntfyBaseUrl = "http://ghost001:2586";
            firewallClosed = true;
          };
        };
      };
    };
}
