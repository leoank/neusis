# Tests for modules/images/oci-base.nix: the base image is a package on
# the Linux systems only, and its `qcow2` attr points into it.
{ self, ... }:
{
  perSystem =
    { lib, ... }:
    {
      tests.image-oci-base = {
        test-package-exists-on-linux-systems-only = {
          expr = lib.mapAttrs (_: p: p ? oci-base-image) self.packages;
          expected = {
            aarch64-linux = true;
            x86_64-linux = true;
            aarch64-darwin = false;
          };
        };

        test-qcow2-path-is-inside-the-image = {
          expr =
            let
              img = self.packages.aarch64-linux.oci-base-image;
            in
            lib.hasPrefix "/nix/store/" img.qcow2 && lib.hasSuffix "/nixos-image-${img.nixosConfig.system.nixos.label}-aarch64-linux.qcow2" img.qcow2;
          expected = true;
        };

        # 1 GiB ESP (lib/cloud.nix), EFI layout as nixpkgs's OCIImage makes it.
        test-esp-is-one-gibibyte = {
          expr =
            let
              preVM = self.packages.aarch64-linux.oci-base-image.drvAttrs.preVM;
            in
            {
              size = lib.hasInfix "numfmt --from=iec '1024M'" preVM;
              esp = lib.hasInfix "mkpart ESP fat32 8MiB $bootSizeMiB" preVM;
            };
          expected = {
            size = true;
            esp = true;
          };
        };
      };
    };
}
