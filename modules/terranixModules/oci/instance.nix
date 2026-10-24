# One compute instance per `neusis.oci.instances.<host>`, bound to a
# neusis machine: the hostname and system come from the registry entry,
# and an assertion refuses an Arm shape for an x86 machine (or the
# reverse). The instance boots the custom image named by `image`
# (looked up, not hard-coded by OCID) and ignores later image or
# metadata changes, so re-baking an image never replaces a running host;
# replacement is always an explicit `-replace`. Optional reserved public
# IP (survives replacement), data volume and boot-volume backup policy.
# Requires `oci-provider` and `oci-network` in the same stack.
#
# Layout note: `config` keeps static top-level keys and merges *inside*
# them — a `mkMerge`/`mkIf` over config-dependent lists at the top of
# `config` recurses in the module system.
{ ... }:
{
  flake.terranixModules.oci-instance =
    { config, lib, ... }:
    let
      cfg = config.neusis.oci;
      ref = lib.tf.ref;

      isArmShape = shape: builtins.match ".*\\.A[0-9]+\\..*" shape != null;
      isArmSystem = system: lib.hasPrefix "aarch64" system;

      insts = lib.mapAttrsToList mkInstance cfg.instances;

      mkInstance = host: inst: rec {
        hostname = inst.machine.hostname;

        assertions = [
          {
            assertion = isArmShape inst.shape.name == isArmSystem inst.machine.system;
            message = "neusis.oci.instances.${host}: shape ${inst.shape.name} does not run ${inst.machine.system} (machine ${hostname})";
          }
          {
            assertion = cfg.network ? ${inst.network};
            message = "neusis.oci.instances.${host}: network \"${inst.network}\" is not declared in neusis.oci.network";
          }
        ];

        data = lib.mkMerge [
          {
            oci_core_images.${host} = {
              compartment_id = cfg.compartment;
              display_name = inst.image;
              state = "AVAILABLE";
              sort_by = "TIMECREATED";
              sort_order = "DESC";
            };
          }
          (lib.mkIf inst.reservedIp {
            oci_core_vnic_attachments.${host} = {
              compartment_id = cfg.compartment;
              instance_id = ref "oci_core_instance.${host}.id";
            };
            oci_core_private_ips.${host}.vnic_id = ref "data.oci_core_vnic_attachments.${host}.vnic_attachments[0].vnic_id";
          })
        ];

        resource = lib.mkMerge [
          {
            oci_core_instance.${host} = {
              compartment_id = cfg.compartment;
              availability_domain = cfg.availabilityDomain;
              display_name = hostname;
              shape = inst.shape.name;
              shape_config = {
                ocpus = inst.shape.ocpus;
                memory_in_gbs = inst.shape.memoryGb;
              };
              source_details = {
                source_type = "image";
                source_id = ref "data.oci_core_images.${host}.images[0].id";
                boot_volume_size_in_gbs = inst.bootVolumeGb;
              };
              create_vnic_details = {
                subnet_id = ref "oci_core_subnet.${inst.network}.id";
                display_name = hostname;
                hostname_label = hostname;
                # The reserved IP is attached below; an ephemeral one
                # would be lost on replacement.
                assign_public_ip = !inst.reservedIp;
              };
              # Arm shapes are UEFI-only; say so explicitly rather than
              # relying on the imported image's launch options (which
              # OCI records as BIOS until the capability schema applies).
              # (OCI insists on network_type whenever launch_options is set)
              launch_options = lib.mkIf (isArmShape inst.shape.name) {
                firmware = "UEFI_64";
                network_type = "PARAVIRTUALIZED";
                boot_volume_type = "PARAVIRTUALIZED";
              };
              # Read by the image's fetch-ssh-keys unit on first boot.
              metadata.ssh_authorized_keys = lib.concatStringsSep "\n" inst.sshAuthorizedKeys;
              preserve_boot_volume = false;
              lifecycle.ignore_changes = [
                "source_details[0].source_id"
                "metadata"
              ];
            };
          }
          (lib.mkIf inst.reservedIp {
            oci_core_public_ip.${host} = {
              compartment_id = cfg.compartment;
              display_name = hostname;
              lifetime = "RESERVED";
              private_ip_id = ref "data.oci_core_private_ips.${host}.private_ips[0].id";
            };
          })
          (lib.mkIf (inst.dataVolumeGb != null) {
            oci_core_volume."${host}-data" = {
              compartment_id = cfg.compartment;
              availability_domain = cfg.availabilityDomain;
              display_name = "${hostname}-data";
              size_in_gbs = inst.dataVolumeGb;
            };
            oci_core_volume_attachment."${host}-data" = {
              attachment_type = "paravirtualized";
              instance_id = ref "oci_core_instance.${host}.id";
              volume_id = ref "oci_core_volume.${host}-data.id";
            };
          })
          (lib.mkIf (inst.backupPolicy != null) {
            oci_core_volume_backup_policy_assignment."${host}-boot" = {
              asset_id = ref "oci_core_instance.${host}.boot_volume_id";
              policy_id = ref "data.oci_core_volume_backup_policies.${inst.backupPolicy}.volume_backup_policies[0].id";
            };
          })
        ];

        output.${host} = {
          ocid = ref "oci_core_instance.${host}.id";
          public_ip =
            if inst.reservedIp then
              ref "oci_core_public_ip.${host}.ip_address"
            else
              ref "oci_core_instance.${host}.public_ip";
          private_ip = ref "oci_core_instance.${host}.private_ip";
        };
      };

      # Oracle-defined policies (no compartment) looked up by name, once
      # per distinct policy in use.
      policies = lib.unique (
        lib.filter (p: p != null) (lib.mapAttrsToList (_: i: i.backupPolicy) cfg.instances)
      );
    in
    {
      options.neusis.oci.instances = lib.mkOption {
        default = { };
        description = "Compute instances, keyed by machine name.";
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              machine = lib.mkOption {
                type = lib.types.attrs;
                example = lib.literalExpression "self.neusis.machines.ghost001";
                description = "The neusis machine (`hostname`, `system`) this instance runs.";
              };
              network = lib.mkOption {
                type = lib.types.str;
                description = "Name of the `neusis.oci.network` to attach to.";
              };
              shape = {
                name = lib.mkOption {
                  type = lib.types.str;
                  default = "VM.Standard.A1.Flex";
                  description = "Compute shape. Must match the machine's architecture.";
                };
                ocpus = lib.mkOption {
                  type = lib.types.int;
                  default = 4;
                };
                memoryGb = lib.mkOption {
                  type = lib.types.int;
                  default = 24;
                };
              };
              bootVolumeGb = lib.mkOption {
                type = lib.types.int;
                default = 50;
                description = "Boot volume size (OCI minimum 50).";
              };
              dataVolumeGb = lib.mkOption {
                type = lib.types.nullOr lib.types.int;
                default = null;
                description = "Optional paravirtualized block volume for application state; survives instance replacement.";
              };
              image = lib.mkOption {
                type = lib.types.str;
                example = "oci-base-aarch64";
                description = "Display name of the custom image to boot (see oci-image).";
              };
              reservedIp = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Attach a reserved public IP instead of an ephemeral one.";
              };
              sshAuthorizedKeys = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                description = "Public keys for root on first boot (instance metadata).";
              };
              backupPolicy = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = "bronze";
                description = "Oracle-defined backup policy for the boot volume (bronze/silver/gold), or null.";
              };
            };
          }
        );
      };

      config = {
        assertions = lib.concatMap (i: i.assertions) insts;
        data = lib.mkMerge (
          map (i: i.data) insts
          ++ map (p: {
            oci_core_volume_backup_policies.${p}.filter = [
              {
                name = "display_name";
                values = [ p ];
              }
            ];
          }) policies
        );
        resource = lib.mkMerge (map (i: i.resource) insts);
        output.instances.value = lib.mkMerge (map (i: i.output) insts);
      };
    };
}
