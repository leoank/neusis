# Tests for flake.terranixModules.oci-network: VCN/subnet wiring and the
# security list, in particular that TCP 22 follows `publicSsh`.
{ self, inputs, ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    let
      eval =
        net:
        (inputs.terranix.lib.evalTerranixConfiguration {
          inherit pkgs;
          modules = [
            self.terranixModules.oci-provider
            self.terranixModules.oci-network
            {
              neusis.oci.network.anklab = net;
            }
          ];
        }).config;

      open = eval { cidr = "10.42.0.0/16"; };
      closed = eval {
        cidr = "10.42.0.0/16";
        publicSsh = false;
      };
      allowlisted = eval {
        cidr = "10.42.0.0/16";
        sshAllowCidrs = [
          "203.0.113.5/32"
          "198.51.100.0/24"
        ];
      };

      tcp22 = cfg: lib.filter (r: r.protocol == "6") cfg.resource.oci_core_security_list.anklab.ingress_security_rules;
    in
    {
      tests.terranix-oci-network = {
        test-vcn-subnet-and-routing-hang-together = {
          expr = {
            vcnCidrs = open.resource.oci_core_vcn.anklab.cidr_blocks;
            subnet = {
              inherit (open.resource.oci_core_subnet.anklab)
                cidr_block
                vcn_id
                route_table_id
                security_list_ids
                ;
            };
            defaultRoute = map (r: r.network_entity_id) open.resource.oci_core_route_table.anklab.route_rules;
            igwVcn = open.resource.oci_core_internet_gateway.anklab.vcn_id;
          };
          expected = {
            vcnCidrs = [ "10.42.0.0/16" ];
            subnet = {
              cidr_block = "10.42.0.0/16";
              vcn_id = "\${oci_core_vcn.anklab.id}";
              route_table_id = "\${oci_core_route_table.anklab.id}";
              security_list_ids = [ "\${oci_core_security_list.anklab.id}" ];
            };
            defaultRoute = [ "\${oci_core_internet_gateway.anklab.id}" ];
            igwVcn = "\${oci_core_vcn.anklab.id}";
          };
        };

        test-ssh-is-open-from-anywhere-by-default = {
          expr = map (r: {
            inherit (r) source;
            port = r.tcp_options.min;
          }) (tcp22 open);
          expected = [
            {
              source = "0.0.0.0/0";
              port = 22;
            }
          ];
        };

        test-public-ssh-off-drops-port-22-but-keeps-icmp-and-tailscale = {
          expr = {
            tcp = tcp22 closed;
            protocols = map (r: r.protocol) closed.resource.oci_core_security_list.anklab.ingress_security_rules;
            tailscale = map (r: r.udp_options.min) (
              lib.filter (r: r.protocol == "17") closed.resource.oci_core_security_list.anklab.ingress_security_rules
            );
          };
          expected = {
            tcp = [ ];
            protocols = [
              "1"
              "17"
            ];
            tailscale = [ 41641 ];
          };
        };

        test-ssh-allowlist-makes-one-rule-per-cidr = {
          expr = map (r: r.source) (tcp22 allowlisted);
          expected = [
            "203.0.113.5/32"
            "198.51.100.0/24"
          ];
        };
      };
    };
}
