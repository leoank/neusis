{
  description = "Neusis: Crafting systems";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-master.url = "github:nixos/nixpkgs/master";

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
      url = "github:nix-community/nixvim/nixos-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix.url = "github:danth/stylix/release-25.05";

    #------------------------------------------------------------

    # wsl
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";

    # darwin inputs
    darwin = {
      url = "github:LnL7/nix-darwin/nix-darwin-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mac-app-util.url = "github:hraban/mac-app-util";
    nix-homebrew = {
      url = "github:zhaofengli-wip/nix-homebrew";
    };
    homebrew-bundle = {
      url = "github:homebrew/homebrew-bundle";
      flake = false;
    };
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
    vancluever-tap = {
      url = "github:vancluever/homebrew-input-leap";
      flake = false;
    };
    fuse-t-cask = {
      url = "github:macos-fuse-t/homebrew-cask";
      flake = false;
    };
    nikitabobko-cask = {
      url = "github:nikitabobko/homebrew-tap";
      flake = false;
    };
    deskflow-tap = {
      url = "github:deskflow/homebrew-tap";
      flake = false;
    };

    felix-kratz-tap = {
      url = "github:FelixKratz/homebrew-formulae";
      flake = false;
    };

    autoraise-tap = {
      url = "github:Dimentium/homebrew-autoraise";
      flake = false;
    };

    # disko
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    # VS Code
    vscode-server.url = "github:nix-community/nixos-vscode-server";

    # Home manager
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix.url = "github:ryantm/agenix";

    hardware.url = "github:nixos/nixos-hardware";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    # Define all the reusable modules for external use
    flake-parts.lib.mkFlake { inherit inputs; } (
      top@{
        withSystem,
        moduleWithSystem,
        flake-parts-lib,
        self,
        lib,
        ...
      }:
      let
        inherit (flake-parts-lib) importApply;

        # Helper
        mkImportApply =
          moduleFileAttrs:
          builtins.mapAttrs (
            name: value:
            importApply value {
              localFlake = self;
              inherit withSystem moduleWithSystem flake-parts-lib;
              #inherit (inputs) nixpkgs;
            }
          ) moduleFileAttrs;

        # Flake modules for external and internal use
        publicFlakeModules = rec {
          default = ./flakeModules/lib.nix;
          neusis = default;

        }
        // mkImportApply rec {
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
            config,
            pkgs,
            inputs',
            self',
            system,
            ...
          }:
          {
            devShells = import ./shell.nix {
              inherit (self) inputs;
              inherit pkgs;
            };

          };

        # Global flake stuff
        flake = rec {
          flakeModules = publicFlakeModules;

          # For backward compat
          flakeModule = flakeModules.default;

          overlays = import ./overlays { inherit (self) inputs outputs; };
          templates = import ./templates;

          # All home configs dynamically generated
          homeConfigurations = self.lib.neusisOS.mkHomeConfigurations {
            machinesRegistry = import ./machines/registry.nix {
              inherit lib;
              nixpkgs = self.inputs.nixpkgs;
              overlays = self.outputs.overlays;
            };
            # FIXME: Hardcoded x86_64-linux breaks Darwin/ARM support
            # See https://github.com/leoank/neusis/pull/32#discussion_r2373029616
            userConfig = import ./users/all.nix {
              inherit self;
              pkgs = import self.inputs.nixpkgs { system = "x86_64-linux"; };
            };
            specialArgs = { inherit (self) inputs outputs; };
          };

        };

      }
    );
}
