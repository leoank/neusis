# supercharged-shell: nix-init module.
# Installs `nix-init`, the "generate a nix derivation from an upstream
# release URL" helper. Pre-populates the `maintainers` field so
# generated derivations don't need you to type your handle every time.
{ ... }:
{
  flake.homeModules.supercharged-shell-nix-init =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.neusis.supercharged-shell.tools.nix-init;
    in
    {
      options.neusis.supercharged-shell.tools.nix-init = {
        enable = lib.mkEnableOption "nix-init derivation scaffolder";

        maintainers = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "ank" ];
          description = "Nixpkgs maintainer handles pre-filled into generated derivations.";
        };
      };

      config = lib.mkIf cfg.enable {
        programs.nix-init = {
          enable = true;
          settings = {
            inherit (cfg) maintainers;
          };
        };
      };
    };
}
