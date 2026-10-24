# Tests for the terranix flake feature (features/flake/terranix.nix +
# _terranix-defaults.nix): the schema entry, and the neusis stack
# defaults evaluated the way a consumer would — a fresh flake-parts
# evaluation of terranix's flake-module plus our defaults module with one
# dummy stack, so nothing leaks into the real flake's `packages`.
{ self, inputs, ... }:
{
  perSystem =
    { lib, system, ... }:
    let
      evalStacks =
        stacks:
        (inputs.flake-parts.lib.evalFlakeModule { inherit inputs; } {
          imports = [
            inputs.terranix.flakeModule
            ../../../features/flake/_terranix-defaults.nix
          ];
          systems = [ system ];
          perSystem = {
            terranix.terranixConfigurations = stacks;
          };
        }).config.allSystems.${system};

      basic = evalStacks {
        demo.modules = [ { output.hello.value = "world"; } ];
      };
      demo = basic.terranix.terranixConfigurations.demo;
      prefix = demo.terraformWrapper.prefixText;

      overridden = evalStacks {
        custom = {
          workdir = "infra/nested/custom";
          terraformWrapper.package = inputs.nixpkgs.legacyPackages.${system}.hello;
        };
      };
    in
    {
      tests.feature-flake-terranix = {
        test-schema-exports-terranix-modules = {
          expr = {
            option = self ? terranixModules;
            modules = builtins.attrNames self.terranixModules;
            flakeModule = self.flakeModules ? terranix;
          };
          expected = {
            option = true;
            modules = [
              "cloudflare-provider"
              "cloudflare-tunnel"
              "oci-image"
              "oci-instance"
              "oci-network"
              "oci-provider"
              "state-encryption"
            ];
            flakeModule = true;
          };
        };

        test-stack-defaults = {
          expr = {
            workdir = demo.workdir;
            engine = lib.getName demo.terraformWrapper.package;
            # `withPlugins` wraps tofu in a derivation whose build script
            # symlinks each pinned provider; look for the OCI one there.
            withPlugins = demo.terraformWrapper.package ? withPlugins;
            ociProvider = lib.hasInfix "terraform-provider-oci" demo.terraformWrapper.package.buildCommand;
            apply = lib.getName basic.packages.demo;
            scripts = lib.sort lib.lessThan (builtins.attrNames demo.result.scripts);
          };
          expected = {
            workdir = "infra/demo";
            engine = "opentofu";
            withPlugins = true;
            ociProvider = true;
            apply = "demo";
            scripts = [
              "apply"
              "destroy"
              "init"
              "plan"
            ];
          };
        };

        test-prefix-guards-relinks-and-loads-secrets = {
          expr = {
            # Climbs out of `infra/demo` to find flake.nix.
            guard = lib.hasInfix "test -f ../../flake.nix" prefix;
            # (compare pieces, not the store path: nix-unit refuses
            # store paths in test values)
            relink = lib.hasInfix "ln -sfn /nix/store/" prefix && lib.hasInfix "-config.tf.json config.tf.json" prefix;
            envFile = lib.hasInfix ''NEUSIS_TF_ENV:-$HOME/.config/neusis/tf.env'' prefix;
            passphrase = lib.hasInfix "TF_VAR_state_passphrase:?" prefix;
          };
          expected = {
            guard = true;
            relink = true;
            envFile = true;
            passphrase = true;
          };
        };

        test-stack-can-override-defaults = {
          expr =
            let
              c = overridden.terranix.terranixConfigurations.custom;
            in
            {
              workdir = c.workdir;
              engine = lib.getName c.terraformWrapper.package;
              # Guard depth follows the overridden workdir.
              guard = lib.hasInfix "test -f ../../../flake.nix" c.terraformWrapper.prefixText;
            };
          expected = {
            workdir = "infra/nested/custom";
            engine = "hello";
            guard = true;
          };
        };
      };
    };
}
