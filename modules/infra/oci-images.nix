# Stack `oci-images`: bake. Uploads the repo-built base image(s) to
# Object Storage and imports them as custom images, A1-compatible with a
# UEFI/paravirtualized capability schema. Separate from `oci-anklab` so
# that a nixpkgs bump (new image) never touches running machines and an
# infra tweak never re-uploads gigabytes (spec §5.2).
#
#   nix run .#oci-images.plan      # builds the image through the Linux
#   nix run .#oci-images.apply     # builders first, then talks to OCI
#
# Working dir infra/oci-images (encrypted state committed there).
{ self, ... }:
{
  perSystem =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      terranix.terranixConfigurations.oci-images.modules = with self.terranixModules; [
        state-encryption
        oci-provider
        oci-image
        {
          neusis.oci.images.oci-base-aarch64 = {
            file = self.packages.aarch64-linux.oci-base-image.qcow2;
            shapes = [ "VM.Standard.A1.Flex" ];
          };
        }
      ];

      checks.tofu-validate-oci-images = self.neusis.lib.cloud.mkValidateCheck {
        inherit pkgs;
        name = "oci-images";
        modules = config.terranix.terranixConfigurations.oci-images.modules;
        # validate stats the upload source; stand in for the (unbuilt)
        # image with any store file.
        extraModules = [ { neusis.oci.images.oci-base-aarch64.file = lib.mkForce "${pkgs.emptyFile}"; } ];
      };
    };
}
