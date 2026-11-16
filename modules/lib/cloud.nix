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
              # nixpkgs's OCIImage, with a 1 GiB ESP instead of make-disk-image's 256 MiB:
              # GRUB copies every kept generation's kernel and initrd onto it (~90 MB each
              # on aarch64), and 249 MB left ghost001 room for one entry (oci-guest).
              # Hosts made from earlier images keep their partitions.
              (
                { config, lib, pkgs, ... }:
                {
                  system.build.OCIImage = lib.mkForce (
                    import (inputs.nixpkgs + "/nixos/lib/make-disk-image.nix") {
                      inherit config lib pkgs;
                      inherit (config.virtualisation) diskSize;
                      name = "oci-image";
                      baseName = config.image.baseName;
                      configFile = inputs.nixpkgs + "/nixos/modules/virtualisation/oci-config-user.nix";
                      format = "qcow2";
                      partitionTableType = if config.oci.efi then "efi" else "legacy";
                      bootSize = "1024M";
                    }
                  );
                }
              )
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

    # T2 check for a stack: render its Terraform JSON and run an offline
    # `tofu init -backend=false && tofu validate` against the Nix-provided
    # providers, so freeform attribute typos fail before any apply.
    # `modules` is the stack's module list; `extraModules` can override
    # what validate cannot resolve in a sandbox (an image file, say).
    mkValidateCheck =
      {
        pkgs,
        name,
        modules,
        extraModules ? [ ],
      }:
      let
        config = inputs.terranix.lib.terranixConfiguration {
          inherit pkgs;
          modules = modules ++ extraModules;
        };
        tofu = pkgs.opentofu.withPlugins (p: [
          p.oracle_oci
          p.cloudflare_cloudflare
        ]);
      in
      pkgs.runCommand "tofu-validate-${name}" { nativeBuildInputs = [ tofu ]; } ''
        export HOME=$TMPDIR
        mkdir work && cd work
        ln -s ${config} config.tf.json
        tofu init -backend=false -input=false >/dev/null
        tofu validate
        touch $out
      '';
  };
}
