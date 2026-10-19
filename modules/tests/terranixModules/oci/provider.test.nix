# Tests for flake.terranixModules.oci-provider: profile-based auth, the
# compartment variable and the shared tenancy lookups.
{ self, inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      cfg =
        (inputs.terranix.lib.evalTerranixConfiguration {
          inherit pkgs;
          modules = [
            self.terranixModules.oci-provider
            { neusis.oci.region = "ap-tokyo-1"; }
          ];
        }).config;
    in
    {
      tests.terranix-oci-provider = {
        test-provider-uses-the-config-profile = {
          expr = {
            inherit (cfg) provider;
            source = cfg.terraform.required_providers.oci.source;
          };
          expected = {
            provider.oci = {
              config_file_profile = "neusis";
              region = "ap-tokyo-1";
            };
            source = "oracle/oci";
          };
        };

        # (the evaluated result is the Terraform JSON, so the
        # `neusis.oci.*` option values are checked through what reads
        # them: the lookups here, `availability_domain` in the instance
        # test, `namespace` in the image test)
        test-compartment-comes-from-a-variable = {
          expr = {
            variable = cfg.variable.compartment_ocid;
            adLookup = cfg.data.oci_identity_availability_domains.ads.compartment_id;
            nsLookup = cfg.data.oci_objectstorage_namespace.ns.compartment_id;
          };
          expected = {
            variable.type = "string";
            adLookup = "\${var.compartment_ocid}";
            nsLookup = "\${var.compartment_ocid}";
          };
        };
      };
    };
}
