# Tests for flake.neusis.lib.cloud.mkOciBaseImage: a host-independent
# qcow2 (no users, secrets or mesh) that still carries the oci-guest
# layout and enough nix to be rebuilt into a real host.
{ self, ... }:
{
  perSystem =
    { lib, ... }:
    let
      t = self.neusis.lib.tests;
      image = self.neusis.lib.cloud.mkOciBaseImage { system = "aarch64-linux"; };
      cfg = image.nixosConfig;
      guest = t.evalNixos {
        system = "aarch64-linux";
        modules = [ self.neusis.features.nixos.oci-guest ];
      };
    in
    {
      tests.lib-cloud = {
        test-base-image-is-an-oci-qcow2-for-the-requested-system = {
          expr = {
            system = cfg.nixpkgs.hostPlatform.system;
            extension = cfg.image.extension;
            tags = cfg.system.nixos.tags;
            efi = cfg.oci.efi;
            qcow2 = lib.hasSuffix "-aarch64-linux.qcow2" image.qcow2;
            isDerivation = lib.isDerivation image;
            stateVersion = cfg.system.stateVersion;
          };
          expected = {
            system = "aarch64-linux";
            extension = "qcow2";
            tags = [ "oci" ];
            efi = true;
            qcow2 = true;
            isDerivation = true;
            stateVersion = "26.05";
          };
        };

        test-base-image-has-no-host-identity = {
          expr = {
            # root (and the nixpkgs system accounts) only
            normalUsers = lib.attrNames (lib.filterAttrs (_: u: u.isNormalUser) cfg.users.users);
            agenix = cfg ? age;
            tailscale = cfg.services.tailscale.enable;
            hostName = cfg.networking.hostName;
            metadataKeys = cfg.systemd.services ? fetch-ssh-keys;
            flakes = cfg.nix.settings.experimental-features;
            failed = t.failedAssertions cfg;
          };
          expected = {
            normalUsers = [ ];
            agenix = false;
            tailscale = false;
            hostName = "oci-base";
            metadataKeys = true;
            flakes = [
              "nix-command"
              "flakes"
            ];
            failed = [ ];
          };
        };

        # The invariant behind base → host `nixos-rebuild switch`: any
        # config importing oci-guest has the image's disk layout.
        test-base-image-and-guest-profile-agree-on-the-disk-layout = {
          expr =
            let
              layout = c: {
                root = c.fileSystems."/".device;
                esp = c.fileSystems."/boot".device;
                grub = {
                  inherit (c.boot.loader.grub) device efiSupport efiInstallAsRemovable;
                };
              };
            in
            layout cfg == layout guest;
          expected = true;
        };

        test-extra-modules-apply = {
          expr =
            (self.neusis.lib.cloud.mkOciBaseImage {
              system = "x86_64-linux";
              extraModules = [ { networking.hostName = "custom"; } ];
            }).nixosConfig.networking.hostName;
          expected = "custom";
        };
      };
    };
}
