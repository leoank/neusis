# Tests for flake.terranixModules.cloudflare-provider: token/account as
# variables, zones declared by name and resolved through a lookup.
{ self, inputs, ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    let
      eval =
        zones:
        (inputs.terranix.lib.evalTerranixConfiguration {
          inherit pkgs;
          modules = [
            self.terranixModules.cloudflare-provider
            { neusis.cloudflare.zones = zones; }
          ];
        }).config;

      two = eval [
        "leoank.me"
        "example-two.org"
      ];
      none = eval [ ];
    in
    {
      tests.terranix-cloudflare-provider = {
        test-credentials-are-variables-not-repo-content = {
          expr = {
            source = two.terraform.required_providers.cloudflare.source;
            token = two.provider.cloudflare.api_token;
            tokenSensitive = two.variable.cloudflare_api_token.sensitive;
            account = two.variable.cloudflare_account_id.type;
          };
          expected = {
            source = "cloudflare/cloudflare";
            token = "\${var.cloudflare_api_token}";
            tokenSensitive = true;
            account = "string";
          };
        };

        test-zones-are-looked-up-by-name = {
          expr = {
            lookups = lib.sort lib.lessThan (builtins.attrNames two.data.cloudflare_zones);
            name = two.data.cloudflare_zones.example_two_org.name;
            # (`zoneId` itself is exercised through the tunnel's CNAMEs)
            # (no zones → no lookup → terranix drops the empty `data` key)
            noZones = (none.data or { }) ? cloudflare_zones;
          };
          expected = {
            lookups = [
              "example_two_org"
              "leoank_me"
            ];
            name = "example-two.org";
            noZones = false;
          };
        };
      };
    };
}
