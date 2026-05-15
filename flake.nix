{
  description = "Neusis: Crafting systems";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # flake-parts
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    # For generating disk images of machines for deployment
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Nixos images for building custom kexec images
    nixos-images.url = "github:nix-community/nixos-images";

    # Auto upgrades
    comin = {
      url = "github:nlewo/comin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # submodule
    astroank = {
      url = "github:leoank/astroank";
      flake = false;
    };

    #------------------------------------------------------------
    # nixvim
    nixvim = {
      url = "github:nix-community/nixvim/nixos-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix.url = "github:danth/stylix/release-25.11";
    stylix.inputs.nixpkgs.follows = "nixpkgs";

    #------------------------------------------------------------

    # wsl
    nixos-wsl.url = "github:nix-community/NixOS-WSL/release-25.11";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # darwin inputs
    darwin = {
      url = "github:LnL7/nix-darwin/nix-darwin-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew = {
      url = "github:zhaofengli-wip/nix-homebrew";
    };
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
    deskflow-tap = {
      url = "github:deskflow/homebrew-tap";
      flake = false;
    };
    pumas-tap = {
      url = "github:graelo/homebrew-tap";
      flake = false;
    };
    whatcable-tap = {
      url = "github:darrylmorley/homebrew-whatcable";
      flake = false;
    };

    # disko
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    # VS Code
    vscode-server.url = "github:nix-community/nixos-vscode-server";

    # Home manager
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";

    hardware.url = "github:nixos/nixos-hardware";

    jail-nix.url = "sourcehut:~alexdavid/jail.nix";
    llm-agents.url = "github:numtide/llm-agents.nix";
    llm-agents.inputs.nixpkgs.follows = "nixpkgs-unstable";
    msgvault = {
      url = "github:wesm/msgvault";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    # Define all the reusable modules for external use
    flake-parts.lib.mkFlake { inherit inputs; } (
      top@{
        config,
        withSystem,
        moduleWithSystem,
        flake-parts-lib,
        ...
      }:
      let
        # Flake modules for external and internal use
        publicFlakeModules = rec {
          default = ./flakeModules/lib.nix;
          neusis = default;

        };
      in
      {
        debug = true;
        systems = [
          "x86_64-linux"
          "aarch64-linux"
          "x86_64-darwin"
          "aarch64-darwin"
        ];

        imports = [
          ./flakeModules/neusisOSConfigs
          ./flakeModules/checks
          ./flakeModules/packages.nix
          ./flakeModules/lib.nix
          ./flakeModules/nixosModules.nix
        ];

        # Per system stuff
        perSystem =
          {
            pkgs,
            ...
          }:
          {
            devShells = import ./shell.nix {
              inherit (top.self) inputs;
              inherit pkgs;
            };

          };

        # Global flake stuff
        flake = rec {
          flakeModules = publicFlakeModules;

          # For backward compat
          flakeModule = flakeModules.default;

          overlays = import ./overlays { inherit (top.self) inputs outputs; };
          templates = import ./templates;

          # All home configs dynamically generated
          homeConfigurations = top.self.lib.neusisOS.mkHomeConfigurations {
            machinesRegistry = import ./machines/registry.nix {
              inherit (top) lib;
              nixpkgs = top.self.inputs.nixpkgs;
              overlays = top.self.outputs.overlays;
            };
            userConfig = import ./users/all.nix {
              inherit (top) self;
            };
            specialArgs = { inherit (top.self) inputs outputs; };
          };

        };

      }
    );
}
