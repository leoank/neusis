{
  description = "Example consumer using flake-parts + neusis (typed schema).";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # In a real consumer: neusis.url = "github:leoank/neusis";
    neusis.url = "path:../..";
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      imports = [
        # Pulls in `flake.users`, `flake.registry`, `flake.lib`
        # option declarations and the `neusisOS` lib implementation.
        # After this, `flake.lib.neusisOS.mkNeusisOS` etc. are
        # available to every module in this flake.
        inputs.neusis.flakeModules.lib

        ./modules/users.nix
        ./modules/registry.nix
        ./modules/systems.nix
      ];
    };
}
