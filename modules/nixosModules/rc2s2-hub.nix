# Neusis rc2s2-hub system module (NixOS only — the hub runs on Linux).
#
# The hub records every rc2s2 node's sessions, events and health over one
# bidirectional gRPC stream per node, and relays a client's decisions
# (allow/deny, answers, prompts, interrupt, kill) back. It is the central,
# always-on piece of rc2s2 (PRJ rc2s2, phase 1 step 6); nodes and clients
# (the phone, `rc2s2 ctl`) connect to it. Registered at
# `flake.nixosModules.rc2s2-hub`; opinionated wiring (secrets, the data
# volume, the self-hosted ntfy) lives in `features/nixos/rc2s2-hub.nix`.
#
# Phase-1 auth is pre-shared tokens read from two files: one of
# `<node name> <token>` lines (`--node-tokens`), one of
# `<client name> <token>` lines (`--client-tokens`). The hub keys peers by
# token, not by name. Both files are agenix secrets, owned by the service
# user. The SQLite record (`--db`) is the source of truth and lives on
# persistent storage so it survives reprovisioning.
#
# Configure via `neusis.services.rc2s2-hub.*`.
{ ... }:
{
  # The rc2s2 workspace flake, which exports the `rc2s2-hub` (this module)
  # and `rc2s2` (the node module) binaries. The node module reads
  # `inputs.rc2s2` too; it is declared once here.
  flake-file.inputs.rc2s2 = {
    # TODO(flip-after-graduation): switch to "github:leoank/rc2s2" once the
    # project has graduated out of the manthan lab and been pushed. The local
    # path lets the modules build and eval before the repo exists.
    url = "path:/Users/ank/workspace/chaos/manthan/rc2s2-a-remote-command-and-control-session-server/main/code/rc2s2-a-remote-command-and-control-session-server";
    inputs.nixpkgs.follows = "nixpkgs-unstable";
  };

  flake.nixosModules.rc2s2-hub =
    {
      config,
      lib,
      pkgs,
      inputs,
      ...
    }:
    let
      cfg = config.neusis.services.rc2s2-hub;
      port = lib.toInt (lib.last (lib.splitString ":" cfg.listen));
    in
    {
      options.neusis.services.rc2s2-hub = {
        enable = lib.mkEnableOption "the rc2s2 hub";

        package = lib.mkOption {
          type = lib.types.package;
          default = inputs.rc2s2.packages.${pkgs.stdenv.hostPlatform.system}.rc2s2-hub;
          defaultText = lib.literalExpression "inputs.rc2s2.packages.\${system}.rc2s2-hub";
          description = "The rc2s2-hub package to run.";
        };

        listen = lib.mkOption {
          type = lib.types.str;
          default = "0.0.0.0:7700";
          example = "100.64.0.1:7700";
          description = ''
            Address nodes and clients connect to. Defaults to all
            interfaces on port 7700; keep the port off any public
            firewall or security list so only the tailnet reaches it
            (`openFirewall` stays false), or bind the tailnet address
            explicitly.
          '';
        };

        dataDir = lib.mkOption {
          type = lib.types.str;
          default = "/var/lib/rc2s2-hub";
          example = "/srv/rc2s2";
          description = ''
            Directory for the SQLite database (`hub.db`). Put it on
            storage that survives reprovisioning; the database is the
            hub's record and is created on first start.
          '';
        };

        nodeTokensFile = lib.mkOption {
          type = lib.types.path;
          description = ''
            File of `<node name> <token>` lines, one per node allowed to
            connect. An agenix secret, readable by the service user.
          '';
        };

        clientTokensFile = lib.mkOption {
          type = lib.types.path;
          description = ''
            File of `<client name> <token>` lines, one per client (the
            phone, `rc2s2 ctl`). An agenix secret, readable by the
            service user.
          '';
        };

        ntfy = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "http://127.0.0.1:2586/rc2s2";
          description = ''
            An ntfy topic URL (`http(s)://host/topic`). The hub posts a
            notification there when a session waits on a person or
            finishes a turn. Registered UnifiedPush endpoints are notified
            regardless; this topic is for anyone subscribed with the ntfy
            app itself. Null disables the topic.
          '';
        };

        user = lib.mkOption {
          type = lib.types.str;
          default = "rc2s2-hub";
          description = "System user the hub runs as and that owns the data directory.";
        };

        group = lib.mkOption {
          type = lib.types.str;
          default = "rc2s2-hub";
          description = "Primary group of the service user.";
        };

        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Open `listen`'s port in the host firewall. Leave false on a
            cloud host so the port is reachable over the tailnet only.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        users.users.${cfg.user} = {
          isSystemUser = true;
          group = cfg.group;
          home = cfg.dataDir;
          description = "rc2s2 hub service user";
        };
        users.groups.${cfg.group} = { };

        systemd.tmpfiles.rules = [
          "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} - -"
        ];

        systemd.services.rc2s2-hub = {
          description = "rc2s2 hub: records nodes' sessions, events and health, relays decisions";
          wantedBy = [ "multi-user.target" ];
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          serviceConfig = {
            ExecStart = lib.escapeShellArgs (
              [
                (lib.getExe cfg.package)
                "--listen"
                cfg.listen
                "--db"
                "${cfg.dataDir}/hub.db"
                "--node-tokens"
                (toString cfg.nodeTokensFile)
                "--client-tokens"
                (toString cfg.clientTokensFile)
              ]
              ++ lib.optionals (cfg.ntfy != null) [
                "--ntfy"
                cfg.ntfy
              ]
            );
            User = cfg.user;
            Group = cfg.group;
            Restart = "on-failure";
            RestartSec = 5;
            # Hardening: the hub needs a TCP listener, its data directory,
            # and to read the token secrets under /run/agenix.
            NoNewPrivileges = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            ReadWritePaths = [ cfg.dataDir ];
            PrivateTmp = true;
            PrivateDevices = true;
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectControlGroups = true;
            RestrictAddressFamilies = [
              "AF_INET"
              "AF_INET6"
            ];
            RestrictNamespaces = true;
            LockPersonality = true;
          };
        };

        networking.firewall = lib.mkIf cfg.openFirewall {
          allowedTCPPorts = [ port ];
        };
      };
    };
}
