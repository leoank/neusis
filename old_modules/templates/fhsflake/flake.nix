{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs_master.url = "github:NixOS/nixpkgs/master";
    systems.url = "github:nix-systems/default";
    flake-utils.url = "github:numtide/flake-utils";
    flake-utils.inputs.systems.follows = "systems";
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      ...
    }@inputs:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          config.cudaSupport = true;
        };

        mpkgs = import inputs.nixpkgs_master {
          inherit system;
          config.allowUnfree = true;
          config.cudaSupport = true;
        };

        fhsenv = pkgs.buildFHSEnv {
          name = "fhs-shell";
          targetPkgs =
            pkgs: with pkgs; [
              gcc
              cudatoolkit
              libGL
              libz
            ];
          profile = '''';
          runScript = "zsh";
        };
      in
      {
        devShells = {
          default = fhsenv.env;
        };
      }
    );
}

# FHS related help
# https://discourse.nixos.org/t/best-way-to-define-common-fhs-environment/25930
# https://ryantm.github.io/nixpkgs/builders/special/fhs-environments/
