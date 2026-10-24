# One Cloudflare Tunnel per `neusis.cloudflare.tunnels.<name>`, bound to a
# neusis machine, with its public hostnames: every `services.<n>` becomes
# an ingress rule of the tunnel's *remotely-managed* configuration and a
# proxied CNAME `<hostname> → <tunnel-id>.cfargotunnel.com` in the zone
# the hostname falls under (longest declared zone suffix wins). The host
# side only needs the tunnel token: `output.tunnel_token_<name>`
# (sensitive) → an agenix secret → `neusis.services.cloudflare-tunnel`.
# Requires `cloudflare-provider` in the same stack.
{ ... }:
{
  flake.terranixModules.cloudflare-tunnel =
    { config, lib, ... }:
    let
      cfg = config.neusis.cloudflare;
      ref = lib.tf.ref;
      tfName = lib.replaceStrings [ "." "-" ] [ "_" "_" ];

      # The declared zone a public hostname belongs to, or null.
      zoneOf =
        hostname:
        let
          matches = lib.filter (z: hostname == z || lib.hasSuffix ".${z}" hostname) cfg.zones;
          longestFirst = lib.sort (a: b: lib.stringLength a > lib.stringLength b) matches;
        in
        if matches == [ ] then null else lib.head longestFirst;

      mkTunnel =
        name: t:
        let
          svcs = lib.mapAttrsToList (sname: s: {
            inherit sname;
            inherit (s) hostname service originRequest;
            zone = zoneOf s.hostname;
          }) t.services;
          tunnelId = ref "cloudflare_zero_trust_tunnel_cloudflared.${name}.id";
        in
        {
          assertions = map (s: {
            assertion = s.zone != null;
            message = "neusis.cloudflare.tunnels.${name}.services.${s.sname}: ${s.hostname} is under none of the declared zones (${toString cfg.zones})";
          }) svcs;

          resource = {
            cloudflare_zero_trust_tunnel_cloudflared.${name} = {
              account_id = cfg.accountId;
              name = t.machine.hostname;
              config_src = "cloudflare";
            };
            cloudflare_zero_trust_tunnel_cloudflared_config.${name} = {
              account_id = cfg.accountId;
              tunnel_id = tunnelId;
              source = "cloudflare";
              # Rules are matched in order; the catch-all must come last.
              config.ingress =
                map (
                  s:
                  {
                    inherit (s) hostname service;
                  }
                  // lib.optionalAttrs (s.originRequest != { }) { origin_request = s.originRequest; }
                ) svcs
                ++ [ { service = "http_status:404"; } ];
            };
          }
          // lib.optionalAttrs (svcs != [ ]) {
            cloudflare_dns_record = lib.listToAttrs (
              map (
                s:
                lib.nameValuePair "${name}_${tfName s.sname}" {
                  zone_id = if s.zone == null then "<no zone>" else cfg.zoneId s.zone;
                  name = s.hostname;
                  type = "CNAME";
                  content = "\${cloudflare_zero_trust_tunnel_cloudflared.${name}.id}.cfargotunnel.com";
                  proxied = true;
                  ttl = 1; # "automatic" (required for proxied records)
                  comment = "neusis: ${name}/${s.sname}";
                }
              ) svcs
            );
          };

          data.cloudflare_zero_trust_tunnel_cloudflared_token.${name} = {
            account_id = cfg.accountId;
            tunnel_id = tunnelId;
          };

          output."tunnel_token_${name}" = {
            value = ref "data.cloudflare_zero_trust_tunnel_cloudflared_token.${name}.token";
            sensitive = true;
          };
        };

      tunnels = lib.mapAttrsToList mkTunnel cfg.tunnels;
    in
    {
      options.neusis.cloudflare.tunnels = lib.mkOption {
        default = { };
        description = "Cloudflare Tunnels, keyed by machine name.";
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              machine = lib.mkOption {
                type = lib.types.attrs;
                example = lib.literalExpression "self.neusis.machines.ghost001";
                description = "The neusis machine running cloudflared (its `hostname` names the tunnel).";
              };
              services = lib.mkOption {
                default = { };
                description = "Public hostnames → services on the machine.";
                type = lib.types.attrsOf (
                  lib.types.submodule {
                    options = {
                      hostname = lib.mkOption {
                        type = lib.types.str;
                        example = "whoami.leoank.me";
                        description = "Public hostname; must fall under one of `neusis.cloudflare.zones`.";
                      };
                      service = lib.mkOption {
                        type = lib.types.str;
                        example = "http://localhost:8080";
                        description = "Origin as cloudflared sees it on the machine (http://, https://, ssh://, tcp://, unix:…).";
                      };
                      originRequest = lib.mkOption {
                        type = lib.types.attrsOf lib.types.anything;
                        default = { };
                        example = {
                          no_tls_verify = true;
                        };
                        description = "Extra `origin_request` settings for this rule (provider attribute names).";
                      };
                    };
                  }
                );
              };
            };
          }
        );
      };

      config = {
        assertions = lib.concatMap (t: t.assertions) tunnels;
        resource = lib.mkMerge (map (t: t.resource) tunnels);
        data = lib.mkMerge (map (t: t.data) tunnels);
        output = lib.mkMerge (map (t: t.output) tunnels);
      };
    };
}
