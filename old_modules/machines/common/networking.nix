{...}: {
  networking.networkmanager.enable = true;
  networking.firewall.enable = false;
  systemd.services.NetworkManager-wait-online.enable = false;
}
