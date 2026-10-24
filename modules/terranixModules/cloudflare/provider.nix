# Cloudflare provider + the account/zone facts the other cloudflare-*
# modules read: `neusis.cloudflare.{accountId,zones,zoneId}`.
#
# The API token and the account id are variables fed by
# `TF_VAR_cloudflare_api_token` / `TF_VAR_cloudflare_account_id` from the
# operator's tf.env (the same file as the OCI facts and the state
# passphrase), so neither lives in the (public) repo. Zones are declared
# by *name*; their ids come from a `cloudflare_zones` lookup.
{ ... }:
{
  flake.terranixModules.cloudflare-provider =
    { config, lib, ... }:
    let
      cfg = config.neusis.cloudflare;
      ref = lib.tf.ref;
      # "leoank.me" → "leoank_me" (a Terraform identifier)
      tfName = lib.replaceStrings [ "." "-" ] [ "_" "_" ];
    in
    {
      options.neusis.cloudflare = {
        accountId = lib.mkOption {
          type = lib.types.str;
          default = ref "var.cloudflare_account_id";
          description = "Cloudflare account id (expression) tunnels are created in.";
        };
        zones = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "leoank.me" ];
          description = "DNS zones this stack manages records in, by name.";
        };
        zoneId = lib.mkOption {
          type = lib.types.functionTo lib.types.str;
          readOnly = true;
          default = zone: ref "data.cloudflare_zones.${tfName zone}.result[0].id";
          description = "Zone name → zone id expression (from the `cloudflare_zones` lookup).";
        };
      };

      config = {
        terraform.required_providers.cloudflare.source = "cloudflare/cloudflare";

        provider.cloudflare.api_token = ref "var.cloudflare_api_token";

        variable.cloudflare_api_token = {
          type = "string";
          sensitive = true;
        };
        variable.cloudflare_account_id.type = "string";

        data.cloudflare_zones = lib.mkIf (cfg.zones != [ ]) (
          lib.listToAttrs (map (z: lib.nameValuePair (tfName z) { name = z; }) cfg.zones)
        );
      };
    };
}
