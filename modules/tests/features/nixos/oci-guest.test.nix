# Tests for flake.neusis.features.nixos.oci-guest: the disk/bootloader
# layout nixpkgs's oci-common gives an OCI guest, and the sshd posture.
{ self, ... }:
{
  perSystem =
    { lib, ... }:
    let
      t = self.neusis.lib.tests;
      cfg = t.evalNixos {
        system = "aarch64-linux";
        modules = [ self.neusis.features.nixos.oci-guest ];
      };
    in
    {
      tests.feature-nixos-oci-guest = {
        test-disk-layout-is-growable-ext4-root-plus-esp = {
          expr = {
            root = {
              inherit (cfg.fileSystems."/") device fsType autoResize;
            };
            esp = {
              inherit (cfg.fileSystems."/boot") device fsType;
            };
            grow = cfg.boot.growPartition;
            grub = {
              inherit (cfg.boot.loader.grub) device efiSupport efiInstallAsRemovable;
            };
            efiVars = cfg.boot.loader.efi.canTouchEfiVariables;
          };
          expected = {
            root = {
              device = "/dev/disk/by-label/nixos";
              fsType = "ext4";
              autoResize = true;
            };
            esp = {
              device = "/dev/disk/by-label/ESP";
              fsType = "vfat";
            };
            grow = true;
            grub = {
              device = "nodev";
              efiSupport = true;
              efiInstallAsRemovable = true;
            };
            efiVars = false;
          };
        };

        test-consoles-ntp-and-networkd = {
          expr = {
            serial = lib.all (p: builtins.elem p cfg.boot.kernelParams) [
              "console=ttyS0"
              "console=ttyAMA0,115200"
            ];
            ntp = cfg.networking.timeServers;
            networkd = cfg.networking.useNetworkd;
          };
          expected = {
            serial = true;
            ntp = [ "169.254.169.254" ];
            networkd = true;
          };
        };

        test-sshd-is-on-and-root-is-key-only = {
          expr = {
            on = cfg.services.openssh.enable;
            inherit (cfg.services.openssh.settings) PermitRootLogin PasswordAuthentication KbdInteractiveAuthentication;
            failed = t.failedAssertions cfg;
          };
          expected = {
            on = true;
            PermitRootLogin = "prohibit-password";
            PasswordAuthentication = false;
            KbdInteractiveAuthentication = false;
            failed = [ ];
          };
        };
      };
    };
}
