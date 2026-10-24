# > Note:  Only import flake part modules with file paths in this file and not with self or config
{ ... }:
{
  flake.flakeModules = {
    # Typed option declarations for `flake.neusis.{users,registry,lib}`.
    # Import this if you want neusis's schema without the bundled
    # builder implementation — e.g. if you want to write your own
    # `mkNeusisOS` variant against the same options.
    options = {
      imports = [
        ./lib/neusis-options.nix
      ];
    };

    # Library implementation only. Must include the options module —
    # without it `flake.neusis` has no declared type, and writing
    # `flake.neusis.lib.neusisOS` from one file and
    # `flake.neusis.lib.utils` from another fails to merge.
    lib = {
      imports = [
        ./lib/neusis-options.nix
        ./lib/neusisOS.nix
        ./lib/utils.nix
      ];
    };

    agenix = {
      imports = [
        ./features/flake/agenix-rekey.nix
      ];
    };

    # terranix input + flake-parts module + the neusis stack defaults
    # (OpenTofu, pinned providers, repo-root guard, secrets env file).
    terranix = {
      imports = [
        ./features/flake/terranix.nix
      ];
    };

    darwin-system-defaults = {
      imports = [
        ./features/darwin/system-defaults.nix
      ];
    };

    # Full neusis integration: option declarations, the bundled
    # `neusisOS` lib (mkNeusisOS, mkAdmin, mergeUserConfigs, …), and the
    # agnostic integration modules the builders reach for via
    # `self.{nixos,darwin}Modules.*` (hm-system-init, secrets). This is
    # the usual import for downstream flake-parts consumers.
    #
    # None of these files declare `flake-file.inputs`, so this bundle
    # works in plain flake-parts flakes as well as dendritic
    # (flake-file) ones.
    default = {
      imports = [
        ./lib/neusis-options.nix
        ./lib/neusisOS.nix
        ./lib/utils.nix
        ./agnosticModules/hm-system-init.nix
        ./agnosticModules/secrets.nix
        ./agnosticModules/re-export-all.nix
        # Cloud machines (spec §7): the terranix modules, the OCI guest
        # profile and `lib.cloud` (base image, validate check). Pair with
        # `flakeModules.terranix` for the stack runner itself.
        ./terranixModules/state-encryption.nix
        ./terranixModules/oci/provider.nix
        ./terranixModules/oci/network.nix
        ./terranixModules/oci/image.nix
        ./terranixModules/oci/instance.nix
        ./features/nixos/oci-guest.nix
        ./lib/cloud.nix
      ];
    };
  };
}
