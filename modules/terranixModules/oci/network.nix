# One VCN + public subnet per `neusis.oci.network.<name>`, with an
# internet gateway, a default route and a security list that admits
# ICMP, tailscale's UDP 41641 and, while `publicSsh` is on, TCP 22 from
# `sshAllowCidrs`. Instances attach by network name
# (`oci_core_subnet.<name>`). Requires `oci-provider` in the same stack.
{ ... }:
{
  flake.terranixModules.oci-network =
    { config, lib, ... }:
    let
      cfg = config.neusis.oci;
      ref = lib.tf.ref;

      anywhere = "0.0.0.0/0";

      mkNetwork =
        name: net:
        let
          ingress =
            [
              {
                description = "ICMP (path MTU discovery, ping)";
                protocol = "1";
                source = anywhere;
              }
              {
                description = "tailscale direct connections";
                protocol = "17";
                source = anywhere;
                udp_options = {
                  min = 41641;
                  max = 41641;
                };
              }
            ]
            ++ lib.optionals net.publicSsh (
              map (cidr: {
                description = "SSH (publicSsh)";
                protocol = "6";
                source = cidr;
                tcp_options = {
                  min = 22;
                  max = 22;
                };
              }) net.sshAllowCidrs
            );
        in
        {
          oci_core_vcn.${name} = {
            compartment_id = cfg.compartment;
            display_name = name;
            dns_label = name;
            cidr_blocks = [ net.cidr ];
          };

          oci_core_internet_gateway.${name} = {
            compartment_id = cfg.compartment;
            display_name = name;
            vcn_id = ref "oci_core_vcn.${name}.id";
          };

          oci_core_route_table.${name} = {
            compartment_id = cfg.compartment;
            display_name = name;
            vcn_id = ref "oci_core_vcn.${name}.id";
            route_rules = [
              {
                destination = anywhere;
                destination_type = "CIDR_BLOCK";
                network_entity_id = ref "oci_core_internet_gateway.${name}.id";
              }
            ];
          };

          oci_core_security_list.${name} = {
            compartment_id = cfg.compartment;
            display_name = name;
            vcn_id = ref "oci_core_vcn.${name}.id";
            egress_security_rules = [
              {
                destination = anywhere;
                protocol = "all";
              }
            ];
            ingress_security_rules = ingress;
          };

          oci_core_subnet.${name} = {
            compartment_id = cfg.compartment;
            display_name = name;
            dns_label = name;
            vcn_id = ref "oci_core_vcn.${name}.id";
            cidr_block = net.cidr;
            route_table_id = ref "oci_core_route_table.${name}.id";
            security_list_ids = [ (ref "oci_core_security_list.${name}.id") ];
          };
        };
    in
    {
      options.neusis.oci.network = lib.mkOption {
        default = { };
        description = "Networks (VCN + one public subnet each), keyed by name.";
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              cidr = lib.mkOption {
                type = lib.types.str;
                example = "10.42.0.0/16";
                description = "CIDR of the VCN and of its single public subnet.";
              };
              publicSsh = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Admit TCP 22 from `sshAllowCidrs`. Off = tailnet-only (plus the serial console).";
              };
              sshAllowCidrs = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ anywhere ];
                description = "Source CIDRs allowed to reach port 22 while `publicSsh` is on.";
              };
            };
          }
        );
      };

      # Merge inside `resource` (a top-level mkMerge over a
      # config-dependent list recurses in the module system).
      config.resource = lib.mkMerge (lib.mapAttrsToList mkNetwork cfg.network);
    };
}
