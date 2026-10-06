{ lib, ... }:
{

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp2s0.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp3s0f0.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp131s0.useDHCP = lib.mkDefault true;

  networking.hostName = "GPFDA-11A";
  networking.hostId = "df6b910c"; # The primary use case is to ensure when using ZFS that a pool isn’t imported accidentally on a wrong machine.

  # networking.bridges.br0.interfaces = [ "enp2s0" "wlp131s0" ];
}
