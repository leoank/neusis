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

    darwin-system-defaults = {
      imports = [
        ./features/darwin/system-defaults.nix
      ];
    };

    # Full neusis integration: option declarations plus the bundled
    # `neusisOS` lib (mkNeusisOS, mkAdmin, mergeUserConfigs, …).
    # This is the usual import for downstream flake-parts consumers.
    default = {
      imports = [
        ./lib/neusis-options.nix
        ./lib/neusisOS.nix
        ./lib/utils.nix
      ];
    };
  };
}
