# Tests for flake.terranixModules.oci-image: object naming from the
# store hash, the import chain, shape compatibility and the capability
# schema. The qcow2 path is a fake store path (plain string, no context).
{ self, inputs, ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    let
      hash = "0123456789abcdfghijklmnpqrsvwxyz";
      eval =
        images:
        (inputs.terranix.lib.evalTerranixConfiguration {
          inherit pkgs;
          modules = [
            self.terranixModules.oci-provider
            self.terranixModules.oci-image
            {
              neusis.oci.images = images;
            }
          ];
        }).config;

      cfg = eval {
        oci-base-aarch64.file = "/nix/store/${hash}-oci-image/nixos.qcow2";
      };
      none = eval { };
    in
    {
      tests.terranix-oci-image = {
        test-object-is-named-after-the-store-hash = {
          expr = {
            inherit (cfg.resource.oci_objectstorage_object.oci-base-aarch64) object source bucket;
            bucketName = cfg.resource.oci_objectstorage_bucket.images.name;
            tag = cfg.resource.oci_core_image.oci-base-aarch64.freeform_tags."neusis-store-hash";
          };
          expected = {
            object = "oci-base-aarch64-${hash}.qcow2";
            source = "/nix/store/${hash}-oci-image/nixos.qcow2";
            bucket = "\${oci_objectstorage_bucket.images.name}";
            bucketName = "neusis-images";
            tag = hash;
          };
        };

        test-image-imports-the-object-as-paravirtualized-qcow2 = {
          expr = {
            inherit (cfg.resource.oci_core_image.oci-base-aarch64) display_name launch_mode lifecycle;
            inherit (cfg.resource.oci_core_image.oci-base-aarch64.image_source_details)
              source_type
              source_image_type
              object_name
              ;
          };
          expected = {
            display_name = "oci-base-aarch64";
            launch_mode = "PARAVIRTUALIZED";
            lifecycle.create_before_destroy = true;
            source_type = "objectStorageTuple";
            source_image_type = "QCOW2";
            object_name = "\${oci_objectstorage_object.oci-base-aarch64.object}";
          };
        };

        test-a1-compatibility-and-uefi-capabilities = {
          expr = {
            shapes = lib.mapAttrsToList (_: s: s.shape_name) cfg.resource.oci_core_shape_management;
            firmware = builtins.fromJSON cfg.resource.oci_core_compute_image_capability_schema.oci-base-aarch64.schema_data."Compute.Firmware";
            capabilities = builtins.attrNames cfg.resource.oci_core_compute_image_capability_schema.oci-base-aarch64.schema_data;
          };
          expected = {
            shapes = [ "VM.Standard.A1.Flex" ];
            firmware = {
              descriptorType = "enumstring";
              source = "IMAGE";
              defaultValue = "UEFI_64";
              values = [ "UEFI_64" ];
            };
            capabilities = [
              "Compute.Firmware"
              "Compute.LaunchMode"
              "Network.AttachmentType"
              "Storage.BootVolumeType"
              "Storage.LocalDataVolumeType"
              "Storage.RemoteDataVolumeType"
            ];
          };
        };

        test-no-images-means-no-resources-at-all = {
          # (terranix drops empty top-level keys from the result)
          expr = none ? resource;
          expected = false;
        };
      };
    };
}
