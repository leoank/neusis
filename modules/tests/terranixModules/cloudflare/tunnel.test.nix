# Tests for flake.terranixModules.cloudflare-tunnel: one tunnel per
# machine with remotely-managed ingress, a proxied CNAME per service in
# the right zone, the token as a sensitive output, and an assertion for
# a hostname outside every declared zone.
{ self, inputs, ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    let
      eval =
        services:
        (inputs.terranix.lib.evalTerranixConfiguration {
          inherit pkgs;
          modules = [
            self.terranixModules.cloudflare-provider
            self.terranixModules.cloudflare-tunnel
            {
              neusis.cloudflare.zones = [
                "leoank.me"
                "lab.leoank.me"
              ];
              neusis.cloudflare.tunnels.ghost001 = {
                machine = {
                  hostname = "ghost001";
                  system = "aarch64-linux";
                };
                inherit services;
              };
            }
          ];
        }).config;

      cfg = eval {
        whoami = {
          hostname = "whoami.leoank.me";
          service = "http://localhost:8080";
        };
        grafana = {
          hostname = "grafana.lab.leoank.me";
          service = "https://localhost:3000";
          originRequest.no_tls_verify = true;
        };
      };
      bare = eval { };
      stray = eval {
        oops = {
          hostname = "oops.example.org";
          service = "http://localhost:1";
        };
      };

      tunnelRef = "\${cloudflare_zero_trust_tunnel_cloudflared.ghost001.id}";
    in
    {
      tests.terranix-cloudflare-tunnel = {
        test-tunnel-is-named-after-the-machine-and-managed-remotely = {
          expr = {
            inherit (cfg.resource.cloudflare_zero_trust_tunnel_cloudflared.ghost001) name config_src account_id;
            configTunnel = cfg.resource.cloudflare_zero_trust_tunnel_cloudflared_config.ghost001.tunnel_id;
            source = cfg.resource.cloudflare_zero_trust_tunnel_cloudflared_config.ghost001.source;
          };
          expected = {
            name = "ghost001";
            config_src = "cloudflare";
            account_id = "\${var.cloudflare_account_id}";
            configTunnel = tunnelRef;
            source = "cloudflare";
          };
        };

        test-ingress-rules-end-with-a-catch-all = {
          expr = {
            rules = map (r: "${r.hostname or "*"} → ${r.service}") cfg.resource.cloudflare_zero_trust_tunnel_cloudflared_config.ghost001.config.ingress;
            originRequest =
              (lib.findFirst (r: (r.hostname or "") == "grafana.lab.leoank.me") null
                cfg.resource.cloudflare_zero_trust_tunnel_cloudflared_config.ghost001.config.ingress
              ).origin_request;
            bareRules = map (r: r.service) bare.resource.cloudflare_zero_trust_tunnel_cloudflared_config.ghost001.config.ingress;
          };
          expected = {
            rules = [
              "grafana.lab.leoank.me → https://localhost:3000"
              "whoami.leoank.me → http://localhost:8080"
              "* → http_status:404"
            ];
            originRequest = {
              no_tls_verify = true;
            };
            bareRules = [ "http_status:404" ];
          };
        };

        test-each-service-is-a-proxied-cname-in-its-longest-zone = {
          expr = {
            records = lib.mapAttrs (_: r: {
              inherit (r)
                name
                type
                content
                proxied
                ttl
                zone_id
                ;
            }) cfg.resource.cloudflare_dns_record;
            bareHasRecords = bare.resource ? cloudflare_dns_record;
          };
          expected = {
            records = {
              ghost001_whoami = {
                name = "whoami.leoank.me";
                type = "CNAME";
                content = "${tunnelRef}.cfargotunnel.com";
                proxied = true;
                ttl = 1;
                zone_id = "\${data.cloudflare_zones.leoank_me.result[0].id}";
              };
              ghost001_grafana = {
                name = "grafana.lab.leoank.me";
                type = "CNAME";
                content = "${tunnelRef}.cfargotunnel.com";
                proxied = true;
                ttl = 1;
                zone_id = "\${data.cloudflare_zones.lab_leoank_me.result[0].id}";
              };
            };
            bareHasRecords = false;
          };
        };

        test-token-is-a-sensitive-output = {
          expr = {
            data = cfg.data.cloudflare_zero_trust_tunnel_cloudflared_token.ghost001.tunnel_id;
            value = cfg.output.tunnel_token_ghost001.value;
            sensitive = cfg.output.tunnel_token_ghost001.sensitive;
          };
          expected = {
            data = tunnelRef;
            value = "\${data.cloudflare_zero_trust_tunnel_cloudflared_token.ghost001.token}";
            sensitive = true;
          };
        };

        # terranix checks `assertions` while rendering, so this throws.
        test-hostname-outside-every-zone-fails-an-assertion = {
          expr = stray.resource;
          expectedError = {
            type = "ThrownError";
            msg = "oops.example.org is under none of the declared zones";
          };
        };
      };
    };
}
