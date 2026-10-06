# supercharged-shell: direnv module.
# Enables `programs.direnv` with `nix-direnv` so `use flake` /
# `use nix` blocks in `.envrc` files cache derivations and don't
# re-evaluate on every shell entry. Zsh integration on by default.
{ ... }:
{
  flake.homeModules.supercharged-shell-direnv =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.neusis.supercharged-shell.tools.direnv;
    in
    {
      options.neusis.supercharged-shell.tools.direnv = {
        enable = lib.mkEnableOption "direnv with nix-direnv";
      };

      config = lib.mkIf cfg.enable {
        programs.direnv = {
          enable = true;
          enableZshIntegration = true;
          nix-direnv.enable = true;
        };
      };
    };
}
