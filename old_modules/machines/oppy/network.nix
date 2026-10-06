# MAC Addresses

# Intel X710 10G SFP+
# enp206s0f0 = 40:a6:b7:cc:d9:00
# enp206s0f1 = 40:a6:b7:cc:d9:01

{ ... }:
let
  infiniband_mac = "80:00:04:cf:fe:80:00:00:00:00:00:00:a0:88:c2:03:00:88:a3:14";
  ether_slave_00_mac = "40:a6:b7:cc:d9:00";
  ether_slave_01_mac = "40:a6:b7:cc:d9:01";
in
{

  networking.hostName = "oppy";
  networking.hostId = "2e39dfae"; # The primary use case is to ensure when using ZFS that a pool isn’t imported accidentally on a wrong machine.

  # Enable infiniband
  hardware.infiniband.enable = true;
  hardware.infiniband.guids = [
    # oppy mellanox port guid
    "0xa088c2030088a314"
  ];

  systemd.network.wait-online.enable = false;
  systemd.services."systemd-networkd".environment.SYSTEMD_LOG_LEVEL = "debug";
  systemd.network = {
    # Enable networkd
    enable = true;
    netdevs = {
      "10-bond001" = {
        netdevConfig = {
          Kind = "bond";
          Name = "bond001";
        };
        bondConfig = {
          Mode = "802.3ad";
          MIIMonitorSec = "100ms";
          TransmitHashPolicy = "layer3+4";
        };
      };
    };
    networks = {
      "30-enp206s0f0" = {
        matchConfig.MACAddress = ether_slave_00_mac;
        networkConfig.Bond = "bond001";
        linkConfig.RequiredForOnline = "yes";
      };

      "30-enp206s0f1" = {
        matchConfig.MACAddress = ether_slave_01_mac;
        networkConfig.Bond = "bond001";
        linkConfig.RequiredForOnline = "yes";
      };

      "40-bond001" = {
        matchConfig.Name = "bond001";
        linkConfig.RequiredForOnline = "no";
        # networkConfig = {
        #   DHCP = "no";
        # };
        # dhcpV4Config = {
        #   # Hostname registered with Broad IT
        #   Hostname = "sn4622121098";
        # };

        # If DHCPv4 fails to work
        networkConfig = {
          Address = "10.192.6.25/24";
          Gateway = "10.192.6.1";
          DNS = [ "10.2.1.1" ];
          DHCP = "no";
        };

        # extraConfig = ''
        #   [Route]
        #   Gateway=10.192.6.1/32
        #   Destination=10.0.6.79/32
        #   Metric=100
        #
        # '';

        #sn4622121097
        # extraConfig = ''
        #   [DHCPv4]
        #   Hostname = sn4622121098
        #
        # '';
      };

      "50-infiniband" = {
        matchConfig.Name = "ibp69s0";
        networkConfig = {
          Address = "192.0.2.1/24";
          DHCP = "no";
        };
        linkConfig.RequiredForOnline = "no";
      };
    };

  };
}
