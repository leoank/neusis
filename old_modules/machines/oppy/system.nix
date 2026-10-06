{ ... }:
{
  # Required for nvidia dc drivers
  services.xserver.enable = false;

  nixpkgs.config.cudaSupport = true;

  # nixos generator settings
  formatConfigs.install-iso =
    { lib, ... }:
    {
      # We can enable it if we make some interface unmanaged
      # networking.networkmanager.unmanaged = [];
      networking.wireless.enable = false;
      neusis.tailscale.hostName = lib.mkForce "install-oppy";

    };
}
