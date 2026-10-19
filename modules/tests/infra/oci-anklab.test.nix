# Tests for the `oci-anklab` stack (modules/infra/oci-anklab.nix):
# ghost001 bound to its registry entry, Always Free sizing, the image name
# shared with `oci-images`, public SSH on (decision §12.8).
{ self, ... }:
{
  perSystem =
    { config, lib, system, ... }:
    let
      stack = config.terranix.terranixConfigurations.oci-anklab;
      tf = stack.result.terraformConfiguration.config;
      images = config.terranix.terranixConfigurations.oci-images.result.terraformConfiguration.config;
      i = tf.resource.oci_core_instance.ghost001;
      m = self.neusis.machines.ghost001;
    in
    {
      tests.infra-oci-anklab = {
        test-ghost001-follows-its-machine-and-the-free-tier = {
          expr = {
            workdir = stack.workdir;
            name = i.display_name == m.hostname;
            shape = "${i.shape}:${toString i.shape_config.ocpus}:${toString i.shape_config.memory_in_gbs}";
            boot = i.source_details.boot_volume_size_in_gbs;
            data = tf.resource.oci_core_volume.ghost001-data.size_in_gbs;
            reserved = tf.resource ? oci_core_public_ip;
            keys = builtins.length (lib.splitString "\n" i.metadata.ssh_authorized_keys);
          };
          expected = {
            workdir = "infra/oci-anklab";
            name = true;
            shape = "VM.Standard.A1.Flex:4:24";
            boot = 50;
            data = 150;
            reserved = true;
            keys = builtins.length self.neusis.users.ank.neusisOS.sshKeys;
          };
        };

        test-image-name-matches-the-images-stack = {
          expr = builtins.elem tf.data.oci_core_images.ghost001.display_name (builtins.attrNames images.resource.oci_core_image);
          expected = true;
        };

        test-public-ssh-is-on-and-the-check-exists = {
          expr = {
            ssh = lib.any (r: r.protocol == "6" && r.tcp_options.min == 22) tf.resource.oci_core_security_list.anklab.ingress_security_rules;
            check = self.checks.${system} ? tofu-validate-oci-anklab;
          };
          expected = {
            ssh = true;
            check = true;
          };
        };
      };
    };
}
