# Hardware profile for a NixOS guest on Oracle Cloud (OCI): nixpkgs's
# `oci-common` (serial/VNC consoles, growable ext4 root by label, ESP,
# GRUB as removable EFI, OCI NTP, networkd, qemu-guest) plus the sshd
# posture the base image boots with (root by key only, from instance
# metadata). Imported by BOTH the base image (lib.cloud.mkOciBaseImage)
# and every OCI host, so a `nixos-rebuild switch` from base to host keeps
# the same disk layout and bootloader — the invariant the base-image
# approach relies on (docs/cloud-terranix-spec.md §4.4).
{ ... }:
{
  flake.neusis.features.nixos.oci-guest =
    { modulesPath, ... }:
    {
      imports = [ "${modulesPath}/virtualisation/oci-common.nix" ];

      services.openssh.settings = {
        PermitRootLogin = "prohibit-password";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
    };
}
