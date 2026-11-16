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

      # The image's ESP is /boot (249 MB) and GRUB copies each generation's kernel and
      # initrd onto it, about 90 MB a kernel on aarch64. GRUB's installer copies the new
      # kernel before it removes the ones no entry needs, so a switch to a new kernel needs
      # room for the kept ones plus the new one: with one entry, two kernels at most. More
      # entries filled /boot on ghost001 (2026-11-14: a 6.18.62 switch stopped at a partial
      # copy and left the menu on the previous generation). Rolling back is still
      # `nixos-rebuild switch --rollback` from the running system; only the boot menu loses
      # the older generations.
      boot.loader.grub.configurationLimit = 1;

      services.openssh.settings = {
        PermitRootLogin = "prohibit-password";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
    };
}
