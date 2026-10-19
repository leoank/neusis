# Custom images from repo-built qcow2 files: one Object Storage bucket,
# and per `neusis.oci.images.<name>` an uploaded object (named after the
# store hash, so a rebuilt image is a new object), an `oci_core_image`
# imported from it, shape compatibility entries, and an image capability
# schema that pins UEFI + paravirtualized boot/network (what the nixpkgs
# OCI image expects). Instances look images up by display name
# (`name`), so the image stack and the machine stack stay independent
# (spec §5.2). Requires `oci-provider` in the same stack.
{ ... }:
{
  flake.terranixModules.oci-image =
    { config, lib, ... }:
    let
      cfg = config.neusis.oci;
      ref = lib.tf.ref;

      bucket = "neusis-images";

      # "/nix/store/<hash>-name/x.qcow2" → "<hash>"
      storeHash =
        file:
        let
          m = builtins.match "${builtins.storeDir}/([a-z0-9]{32})-.*" file;
        in
        if m == null then throw "neusis.oci.images: `file` must be inside a store path, got ${file}" else lib.head m;

      # Terraform resource names allow [A-Za-z0-9_-].
      sanitize = s: lib.replaceStrings [ "." ] [ "-" ] s;

      capability = kind: value: builtins.toJSON {
        descriptor_type = kind;
        source = "IMAGE";
        default_value = value;
        values = [ value ];
      };

      mkImage =
        name: img:
        let
          hash = storeHash img.file;
          object = "${name}-${hash}.qcow2";
        in
        {
          oci_objectstorage_object.${name} = {
            namespace = cfg.namespace;
            bucket = ref "oci_objectstorage_bucket.images.name";
            object = object;
            source = img.file;
            content_type = "application/octet-stream";
          };

          oci_core_image.${name} = {
            compartment_id = cfg.compartment;
            display_name = name;
            launch_mode = "PARAVIRTUALIZED";
            image_source_details = {
              source_type = "objectStorageTuple";
              namespace_name = cfg.namespace;
              bucket_name = ref "oci_objectstorage_bucket.images.name";
              object_name = ref "oci_objectstorage_object.${name}.object";
              source_image_type = "QCOW2";
              operating_system = "NixOS";
            };
            freeform_tags."neusis.store-hash" = hash;
            # A new image exists before the old one goes; instances ignore
            # the change (oci-instance) so nothing gets replaced.
            lifecycle.create_before_destroy = true;
            timeouts.create = "60m";
          };

          oci_core_compute_image_capability_schema.${name} = {
            compartment_id = cfg.compartment;
            display_name = name;
            image_id = ref "oci_core_image.${name}.id";
            compute_global_image_capability_schema_version_name =
              ref "data.oci_core_compute_global_image_capability_schemas.global.compute_global_image_capability_schemas[0].current_version_name";
            schema_data = {
              "Compute.Firmware" = capability "enumstring" "UEFI_64";
              "Compute.LaunchMode" = capability "enumstring" "PARAVIRTUALIZED";
              "Network.AttachmentType" = capability "enumstring" "PARAVIRTUALIZED";
              "Storage.BootVolumeType" = capability "enumstring" "PARAVIRTUALIZED";
              "Storage.RemoteDataVolumeType" = capability "enumstring" "PARAVIRTUALIZED";
              "Storage.LocalDataVolumeType" = capability "enumstring" "PARAVIRTUALIZED";
            };
          };

          oci_core_shape_management = lib.listToAttrs (
            map (shape: {
              name = "${name}-${sanitize shape}";
              value = {
                compartment_id = cfg.compartment;
                image_id = ref "oci_core_image.${name}.id";
                shape_name = shape;
              };
            }) img.shapes
          );
        };
    in
    {
      options.neusis.oci.images = lib.mkOption {
        default = { };
        description = "Custom images to upload and import, keyed by the display name instances refer to.";
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              file = lib.mkOption {
                type = lib.types.str;
                example = lib.literalExpression ''"''${self.packages.aarch64-linux.oci-base-image}/nixos.qcow2"'';
                description = "Path to the qcow2 inside a store path; its hash names the uploaded object.";
              };
              shapes = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ "VM.Standard.A1.Flex" ];
                description = "Shapes the image is marked compatible with.";
              };
            };
          }
        );
      };

      # Static top-level keys with the merge inside each (a `mkIf` over
      # the whole `config` recurses in the module system).
      config = {
        resource = lib.mkIf (cfg.images != { }) (
          lib.mkMerge (
            [
              {
                oci_objectstorage_bucket.images = {
                  compartment_id = cfg.compartment;
                  namespace = cfg.namespace;
                  name = bucket;
                  access_type = "NoPublicAccess";
                };
              }
            ]
            ++ lib.mapAttrsToList mkImage cfg.images
          )
        );
        # Global schemas are tenancy-scoped: listing them filtered by our
        # compartment returns nothing, so no arguments at all (terranix
        # keeps an empty block as long as its top-level key is not empty).
        data.oci_core_compute_global_image_capability_schemas.global = lib.mkIf (cfg.images != { }) { };
      };
    };
}
