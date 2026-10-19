# Tests for flake.terranixModules.oci-instance: machine binding, the
# arch/shape assertion, image lookup by name with ignore_changes, the
# reserved IP, optional data volume and backup policy, and outputs.
{ self, inputs, ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    let
      arm = {
        hostname = "ghost001";
        system = "aarch64-linux";
      };
      x86 = {
        hostname = "box";
        system = "x86_64-linux";
      };

      eval =
        instances:
        (inputs.terranix.lib.evalTerranixConfiguration {
          inherit pkgs;
          modules = [
            self.terranixModules.oci-provider
            self.terranixModules.oci-network
            self.terranixModules.oci-instance
            {
              neusis.oci.network.anklab.cidr = "10.42.0.0/16";
              neusis.oci.instances = instances;
            }
          ];
        }).config;

      base = {
        machine = arm;
        network = "anklab";
        image = "oci-base-aarch64";
        sshAuthorizedKeys = [
          "ssh-ed25519 AAAA1 a"
          "ssh-ed25519 AAAA2 b"
        ];
      };

      full = eval {
        ghost001 = base // {
          dataVolumeGb = 100;
        };
      };
      minimal = eval {
        ghost001 = base // {
          reservedIp = false;
          backupPolicy = null;
        };
      };
      i = full.resource.oci_core_instance.ghost001;
    in
    {
      tests.terranix-oci-instance = {
        test-instance-follows-the-machine-and-the-defaults = {
          expr = {
            inherit (i)
              display_name
              shape
              shape_config
              availability_domain
              ;
            boot = i.source_details.boot_volume_size_in_gbs;
            subnet = i.create_vnic_details.subnet_id;
            keys = i.metadata.ssh_authorized_keys;
          };
          expected = {
            display_name = "ghost001";
            shape = "VM.Standard.A1.Flex";
            shape_config = {
              ocpus = 4;
              memory_in_gbs = 24;
            };
            availability_domain = "\${data.oci_identity_availability_domains.ads.availability_domains[0].name}";
            boot = 50;
            subnet = "\${oci_core_subnet.anklab.id}";
            keys = "ssh-ed25519 AAAA1 a\nssh-ed25519 AAAA2 b";
          };
        };

        test-image-is-looked-up-by-name-and-then-ignored = {
          expr = {
            lookup = {
              inherit (full.data.oci_core_images.ghost001) display_name state sort_by sort_order;
            };
            source = i.source_details.source_id;
            ignored = i.lifecycle.ignore_changes;
          };
          expected = {
            lookup = {
              display_name = "oci-base-aarch64";
              state = "AVAILABLE";
              sort_by = "TIMECREATED";
              sort_order = "DESC";
            };
            source = "\${data.oci_core_images.ghost001.images[0].id}";
            ignored = [
              "source_details[0].source_id"
              "metadata"
            ];
          };
        };

        test-reserved-ip-data-volume-and-backup-policy = {
          expr = {
            ephemeralIp = i.create_vnic_details.assign_public_ip;
            reserved = {
              inherit (full.resource.oci_core_public_ip.ghost001) lifetime private_ip_id;
            };
            volume = full.resource.oci_core_volume.ghost001-data.size_in_gbs;
            attachment = {
              inherit (full.resource.oci_core_volume_attachment.ghost001-data) attachment_type volume_id;
            };
            backup = full.resource.oci_core_volume_backup_policy_assignment.ghost001-boot.asset_id;
            policyLookup = full.data.oci_core_volume_backup_policies.bronze.filter;
            output = full.output.instances.value.ghost001;
          };
          expected = {
            ephemeralIp = false;
            reserved = {
              lifetime = "RESERVED";
              private_ip_id = "\${data.oci_core_private_ips.ghost001.private_ips[0].id}";
            };
            volume = 100;
            attachment = {
              attachment_type = "paravirtualized";
              volume_id = "\${oci_core_volume.ghost001-data.id}";
            };
            backup = "\${oci_core_instance.ghost001.boot_volume_id}";
            policyLookup = [
              {
                name = "display_name";
                values = [ "bronze" ];
              }
            ];
            output = {
              ocid = "\${oci_core_instance.ghost001.id}";
              public_ip = "\${oci_core_public_ip.ghost001.ip_address}";
              private_ip = "\${oci_core_instance.ghost001.private_ip}";
            };
          };
        };

        test-minimal-instance-has-ephemeral-ip-and-nothing-optional = {
          expr = {
            ephemeralIp = minimal.resource.oci_core_instance.ghost001.create_vnic_details.assign_public_ip;
            resources = lib.sort lib.lessThan (builtins.attrNames minimal.resource);
            data = lib.sort lib.lessThan (builtins.attrNames minimal.data);
            ip = minimal.output.instances.value.ghost001.public_ip;
          };
          expected = {
            ephemeralIp = true;
            resources = [
              "oci_core_instance"
              "oci_core_internet_gateway"
              "oci_core_route_table"
              "oci_core_security_list"
              "oci_core_subnet"
              "oci_core_vcn"
            ];
            data = [
              "oci_core_images"
              "oci_identity_availability_domains"
              "oci_objectstorage_namespace"
            ];
            ip = "\${oci_core_instance.ghost001.public_ip}";
          };
        };

        test-arm-machine-on-x86-shape-is-refused = {
          expr = (eval { ghost001 = base // { shape.name = "VM.Standard.E4.Flex"; }; }).resource;
          expectedError = {
            type = "ThrownError";
            msg = "shape VM.Standard.E4.Flex does not run aarch64-linux";
          };
        };

        test-x86-machine-on-a1-shape-is-refused = {
          expr = (eval { box = base // { machine = x86; }; }).resource;
          expectedError = {
            type = "ThrownError";
            msg = "shape VM.Standard.A1.Flex does not run x86_64-linux";
          };
        };

        test-unknown-network-is-refused = {
          expr = (eval { ghost001 = base // { network = "nope"; }; }).resource;
          expectedError = {
            type = "ThrownError";
            msg = "network \"nope\" is not declared";
          };
        };
      };
    };
}
