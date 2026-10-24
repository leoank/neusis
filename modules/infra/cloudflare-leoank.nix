# Stack `cloudflare-leoank`: public hostnames under leoank.me for services
# on the cloud hosts, through Cloudflare Tunnels (no inbound ports). One
# tunnel per machine; each `services.<n>` is a proxied CNAME + an ingress
# rule of the tunnel's remotely-managed config, so adding a public
# subdomain is one attribute here + `apply` (the host needs no change —
# it runs cloudflared with the tunnel token, see ghost001.nix).
#
#   nix run .#cloudflare-leoank.plan / .apply
#   nix run .#cloudflare-leoank.terraform -- output -raw tunnel_token_ghost001
#
# Needs TF_VAR_cloudflare_api_token + TF_VAR_cloudflare_account_id in the
# operator's tf.env. Working dir infra/cloudflare-leoank (encrypted state
# committed there).
{ self, ... }:
{
  perSystem =
    { config, pkgs, ... }:
    {
      checks.tofu-validate-cloudflare-leoank = self.neusis.lib.cloud.mkValidateCheck {
        inherit pkgs;
        name = "cloudflare-leoank";
        modules = config.terranix.terranixConfigurations.cloudflare-leoank.modules;
      };

      terranix.terranixConfigurations.cloudflare-leoank.modules = with self.terranixModules; [
        state-encryption
        cloudflare-provider
        cloudflare-tunnel
        {
          neusis.cloudflare.zones = [ "leoank.me" ];

          neusis.cloudflare.tunnels.ghost001 = {
            machine = self.neusis.machines.ghost001;
            # Public hostname → origin on ghost001. Example:
            #   whoami.hostname = "whoami.leoank.me";
            #   whoami.service = "http://localhost:8080";
            services = { };
          };
        }
      ];
    };
}
