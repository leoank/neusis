# supercharged-shell: nix-search-tv module.
# Hooks nix-search-tv into television so you can fuzzy-search
# nixpkgs / nixos options / home-manager options from inside `tv`.
# Requires the television tool to actually be useful — enable both.
{ ... }:
{
  flake.homeModules.supercharged-shell-nix-search-tv =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.neusis.supercharged-shell.tools.nix-search-tv;
    in
    {
      options.neusis.supercharged-shell.tools.nix-search-tv = {
        enable = lib.mkEnableOption "nix-search-tv (television channel for nixpkgs/options)";
      };

      config = lib.mkIf cfg.enable {
        programs.nix-search-tv = {
          enable = true;
          enableTelevisionIntegration = true;
        };
      };
    };
}
