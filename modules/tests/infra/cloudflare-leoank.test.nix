# Tests for the `cloudflare-leoank` stack (modules/infra/cloudflare-leoank.nix):
# the leoank.me zone, ghost001's tunnel bound to its machine, the token
# output the host secret is filled from, and the validate check.
{ self, ... }:
{
  perSystem =
    { config, system, ... }:
    let
      stack = config.terranix.terranixConfigurations.cloudflare-leoank;
      tf = stack.result.terraformConfiguration.config;
    in
    {
      tests.infra-cloudflare-leoank = {
        test-ghost001-tunnel-under-leoank-me = {
          expr = {
            workdir = stack.workdir;
            zones = builtins.attrNames tf.data.cloudflare_zones;
            tunnel = tf.resource.cloudflare_zero_trust_tunnel_cloudflared.ghost001.name == self.neusis.machines.ghost001.hostname;
            catchAll = (builtins.head (
              builtins.filter (r: !(r ? hostname)) tf.resource.cloudflare_zero_trust_tunnel_cloudflared_config.ghost001.config.ingress
            )).service;
            tokenOutput = tf.output ? tunnel_token_ghost001;
            encrypted = tf.terraform.encryption.state.enforced;
            check = self.checks.${system} ? tofu-validate-cloudflare-leoank;
          };
          expected = {
            workdir = "infra/cloudflare-leoank";
            zones = [ "leoank_me" ];
            tunnel = true;
            catchAll = "http_status:404";
            tokenOutput = true;
            encrypted = true;
            check = true;
          };
        };
      };
    };
}
