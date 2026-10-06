{
  description = "Example consumer using flake-parts + neusis (typed schema).";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
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
        # Pulls in the `flake.neusis.{users,registry,machines,lib}`
        # option declarations, the `neusisOS` lib implementation and the
        # hm-system-init / secrets integration modules (exported as
        # `nixosModules` / `darwinModules`, which `mkNeusisOS` reaches for
        # via `self`). After this, `self.neusis.lib.neusisOS.mkNeusisOS`
        # etc. are available to every module in this flake.
        # `flakeModules.lib` is the schema + lib only — use it if you wire
        # the integration modules yourself.
        inputs.neusis.flakeModules.default

        ./modules/users.nix
        ./modules/registry.nix
        ./modules/systems.nix
      ];
    };
}
