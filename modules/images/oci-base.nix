# `packages.<linux-system>.oci-base-image`: the shared OCI base image for
# that architecture (see lib/cloud.nix). Built through the Linux builders
# from a Mac; the `oci-images` stack uploads `.qcow2` of the one it needs.
{ self, ... }:
{
  perSystem =
    {
      pkgs,
      lib,
      system,
      ...
    }:
    {
      packages = lib.optionalAttrs pkgs.stdenv.isLinux {
        oci-base-image = self.neusis.lib.cloud.mkOciBaseImage { inherit system; };
      };
    };
}
