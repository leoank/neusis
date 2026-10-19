# OCI provider + the tenancy facts every other oci-* module reads:
# `neusis.oci.{compartment,availabilityDomain,namespace}`.
#
# Credentials come from the operator's `~/.oci/config` profile (an HM
# agenix secret), never from Nix. The region and compartment OCID are
# variables fed by `TF_VAR_region` / `TF_VAR_compartment_ocid` from the
# same env file as the state passphrase, which keeps every tenancy fact
# out of the (public) repo.
{ ... }:
{
  flake.terranixModules.oci-provider =
    { config, lib, ... }:
    let
      cfg = config.neusis.oci;
    in
    {
      options.neusis.oci = {
        profile = lib.mkOption {
          type = lib.types.str;
          default = "neusis";
          description = "Profile in ~/.oci/config holding the API key for this stack.";
        };
        region = lib.mkOption {
          type = lib.types.str;
          default = lib.tf.ref "var.region";
          example = "ap-tokyo-1";
          description = "OCI region identifier (expression). Always Free A1 capacity exists only in the home region.";
        };
        compartment = lib.mkOption {
          type = lib.types.str;
          default = lib.tf.ref "var.compartment_ocid";
          description = "Compartment OCID (expression) every resource is created in.";
        };
        availabilityDomain = lib.mkOption {
          type = lib.types.str;
          default = lib.tf.ref "data.oci_identity_availability_domains.ads.availability_domains[0].name";
          description = "Availability domain (expression) for instances and volumes. The first AD by default.";
        };
        namespace = lib.mkOption {
          type = lib.types.str;
          default = lib.tf.ref "data.oci_objectstorage_namespace.ns.namespace";
          readOnly = true;
          description = "Object Storage namespace of the tenancy (expression).";
        };
      };

      config = {
        terraform.required_providers.oci.source = "oracle/oci";

        provider.oci = {
          config_file_profile = cfg.profile;
          region = cfg.region;
        };

        variable.region.type = "string";
        variable.compartment_ocid.type = "string";

        data.oci_identity_availability_domains.ads.compartment_id = cfg.compartment;
        data.oci_objectstorage_namespace.ns.compartment_id = cfg.compartment;
      };
    };
}
