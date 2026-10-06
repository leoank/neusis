{...}: let
  publicDnsServer = "8.8.8.8";
in {
  boot.kernel.sysctl = {
    "net.ipv4.conf.all.forwarding" = true;
    # "net.ipv6.conf.all.forwarding" = true;

    # source: https://github.com/mdlayher/homelab/blob/master/nixos/routnerr-2/configuration.nix#L52
    # By default, not automatically configure any IPv6 addresses.
    # "net.ipv6.conf.all.accept_ra" = 0;
    # "net.ipv6.conf.all.autoconf" = 0;
    # "net.ipv6.conf.all.use_tempaddr" = 0;

    # On WAN, allow IPv6 autoconfiguration and tempory address use.
    # "net.ipv6.conf.${name}.accept_ra" = 2;
    # "net.ipv6.conf.${name}.autoconf" = 1;
  };
  networking.interfaces = {
    # enp3s0f0 = {
    #   useDHCP = true;
    # };
    enp2s0 = {
      useDHCP = false;
      ipv4.addresses = [
        {
          address = "10.13.84.1";
          prefixLength = 24;
        }
      ];
    };
  };
  networking.nftables.enable = true;
  networking.nftables.ruleset = ''
    table ip nat {
        chain postrouting {
          type nat hook postrouting priority srcnat; policy accept;
          oifname "enp3s0f0" counter masquerade
        }
    }

    table ip6 filter {
      chain input {
        type filter hook input priority 0; policy drop;
      }
      chain forward {
        type filter hook forward priority 0; policy drop;
      }
    }
  '';

  services.kea.dhcp4 = {
    enable = false;
    settings = {
      interfaces-config = {
        interfaces = ["enp2s0"];
      };
      subnet4 = [
        {
          subnet = "10.13.84.1/24";
          interface = "enp2s0";
          option-data = [
            {
              name = "domain-name-servers";
              data = "${publicDnsServer}";
            }
            {
              name = "routers";
              data = "10.13.84.1";
            }
            {
              name = "subnet-mask";
              data = "255.255.255.0";
            }
          ];
          pools = [
            {
              pool = "10.13.84.2 - 10.13.84.254";
            }
          ];
        }
      ];
    };

    # extraConfig = ''
    #   subnet 10.13.84.0 netmask 255.255.255.0 {
    #     option routers 10.13.84.1;
    #     option domain-name-servers ${publicDnsServer};
    #     option subnet-mask 255.255.255.0;
    #     interface enp2s0;
    #     range 10.13.84.2 10.13.84.254;
    #   }
    # '';
  };
}
