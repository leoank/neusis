{ inputs, ... }:
{
  flake-file.inputs = {
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # Enable support for exporting flake.homeConfiguration and flake.homeModules with type support
  imports = [
    inputs.home-manager.flakeModules.home-manager
  ];
}
