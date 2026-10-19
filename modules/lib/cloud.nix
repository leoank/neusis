# Cloud helpers: `flake.neusis.lib.cloud`.
{ self, inputs, ... }:
{
  flake.neusis.lib.cloud = {
    # The qcow2 every OCI host first boots: nixpkgs's OCI image module +
    # the `oci-guest` profile, nothing host-specific (no users, secrets or
    # mesh), so one image per architecture serves the whole fleet and is
    # safe to keep in Object Storage. Returns the image derivation with
    # `qcow2` (path of the file inside it, what `neusis.oci.images.<n>.file`
    # takes) and `nixosConfig` as extra attributes.
    mkOciBaseImage =
      {
        system,
        extraModules ? [ ],
      }:
      let
        cfg =
          (inputs.nixpkgs.lib.nixosSystem {
            specialArgs = {
              inherit inputs;
              outputs = self;
            };
            modules = [
              "${inputs.nixpkgs}/nixos/modules/virtualisation/oci-image.nix"
              self.neusis.features.nixos.oci-guest
              {
                nixpkgs.hostPlatform = system;
                networking.hostName = inputs.nixpkgs.lib.mkDefault "oci-base";
                # Enough nix for `nixos-rebuild --target-host root@…` to
                # push the real host config; the host brings its own
                # settings (substituters, registry, …).
                nix.settings.experimental-features = [
                  "nix-command"
                  "flakes"
                ];
                # Release the image was created under; hosts set their own.
                system.stateVersion = "26.05";
              }
            ]
            ++ extraModules;
          }).config;
        image = cfg.system.build.OCIImage;
      in
      image
      // {
        qcow2 = "${image}/${cfg.image.fileName}";
        nixosConfig = cfg;
      };
  };
}
