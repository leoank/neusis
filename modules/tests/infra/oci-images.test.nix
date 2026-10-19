# Tests for the `oci-images` stack (modules/infra/oci-images.nix): it
# bakes the repo's aarch64 base image under the name the machine stack
# looks up, and ships the validate check.
{ self, ... }:
{
  perSystem =
    { config, lib, system, ... }:
    let
      stack = config.terranix.terranixConfigurations.oci-images;
      tf = stack.result.terraformConfiguration.config;
    in
    {
      tests.infra-oci-images = {
        test-bakes-the-aarch64-base-image = {
          expr = {
            workdir = stack.workdir;
            images = builtins.attrNames tf.resource.oci_core_image;
            # the uploaded file is the repo-built image, by store path
            source = lib.hasPrefix "/nix/store/" tf.resource.oci_objectstorage_object.oci-base-aarch64.source
              && lib.hasSuffix "-aarch64-linux.qcow2" tf.resource.oci_objectstorage_object.oci-base-aarch64.source;
            shapes = lib.mapAttrsToList (_: s: s.shape_name) tf.resource.oci_core_shape_management;
            encrypted = tf.terraform.encryption.state.enforced;
            check = self.checks.${system} ? tofu-validate-oci-images;
          };
          expected = {
            workdir = "infra/oci-images";
            images = [ "oci-base-aarch64" ];
            source = true;
            shapes = [ "VM.Standard.A1.Flex" ];
            encrypted = true;
            check = true;
          };
        };
      };
    };
}
