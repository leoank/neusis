# Cloudflare Tunnel connector: runs `cloudflared` for a tunnel whose
# ingress rules are managed remotely (declared in a terranix stack, see
# terranixModules/cloudflare/tunnel.nix), so the host needs nothing but
# the tunnel token. The token file (an agenix secret) is handed to the
# unit as a systemd credential; it never enters the store.
#
# NixOS only (systemd). Lives in agnosticModules so it is re-exported as
# `nixosModules.cloudflare-tunnel`; enabling it on Darwin fails an
# assertion rather than silently doing nothing.
{ ... }:
{
  flake.agnosticModules.cloudflare-tunnel =
    {
      config,
      options,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.neusis.services.cloudflare-tunnel;
      isLinux = options ? systemd;
    in
    {
      options.neusis.services.cloudflare-tunnel = {
        enable = lib.mkEnableOption "a cloudflared connector for a remotely-managed Cloudflare Tunnel";

        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.cloudflared;
          defaultText = lib.literalExpression "pkgs.cloudflared";
          description = "The cloudflared package.";
        };

        tokenFile = lib.mkOption {
          type = lib.types.str;
          example = "/run/agenix/cfTunnelToken";
          description = ''
            File holding the tunnel token (`nix run .#<stack>.terraform --
            output -raw tunnel_token_<host>`, stored as an agenix secret).
            Read by systemd as a credential; may be root-only.
          '';
        };
      };

      config = lib.mkMerge [
        {
          assertions = [
            {
              assertion = !cfg.enable || isLinux;
              message = "neusis.services.cloudflare-tunnel: NixOS only (cloudflared runs under systemd)";
            }
          ];
        }

        (lib.optionalAttrs isLinux {
          systemd.services.cloudflared-tunnel = lib.mkIf cfg.enable {
            description = "Cloudflare Tunnel connector (remotely-managed config)";
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              ExecStart = "${cfg.package}/bin/cloudflared tunnel --no-autoupdate run --token-file %d/token";
              LoadCredential = [ "token:${cfg.tokenFile}" ];
              DynamicUser = true;
              Restart = "on-failure";
              RestartSec = "5s";
              NoNewPrivileges = true;
              PrivateTmp = true;
              ProtectSystem = "strict";
              ProtectHome = true;
            };
          };
        })
      ];
    };
}
