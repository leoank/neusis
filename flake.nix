{
  description = "Neusis: Crafting systems";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-master.url = "github:nixos/nixpkgs/master";

    # submodule
    astroank = {
      url = "github:leoank/astroank";
      flake = false;
    };

    #------------------------------------------------------------
    # nixvim
    nixvim = {
      url = "github:nix-community/nixvim/nixos-24.11";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    stylix.url = "github:danth/stylix/release-24.11";

    minty = {
      url = "github:NvChad/minty";
      flake = false;
    };

    volt = {
      url = "github:NvChad/volt";
      flake = false;
    };

    nvim-window-picker = {
      url = "github:s1n7ax/nvim-window-picker";
      flake = false;
    };

    #------------------------------------------------------------

    # wsl
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";

    # darwin inputs
    darwin = {
      url = "github:LnL7/nix-darwin/nix-darwin-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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

    # system and flake util
    systems.url = "github:nix-systems/default";

    # disko
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    # VS Code
    vscode-server.url = "github:nix-community/nixos-vscode-server";

    # Home manager
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix.url = "github:ryantm/agenix";

    hardware.url = "github:nixos/nixos-hardware";

    nix-colors.url = "github:misterio77/nix-colors";

    nh = {
      url = "github:viperml/nh";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland = {
      url = "github:hyprwm/hyprland";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprwm-contrib = {
      url = "github:hyprwm/contrib";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };

  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      systems,
      ...
    }@inputs:
    let
      inherit (self) outputs;
      lib = nixpkgs.lib // home-manager.lib;
      forEachSystem = f: lib.genAttrs (import systems) (system: f pkgsFor.${system});
      pkgsFor = lib.genAttrs (import systems) (
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        }
      );
    in
    {
      inherit lib;

      # custom modules
      nixosModules = import ./modules/nixos { inherit inputs outputs; };
      homeManagerModules = import ./modules/home-manager;

      overlays = import ./overlays { inherit inputs outputs; };

      packages = forEachSystem (pkgs: import ./pkgs { inherit pkgs inputs outputs; });
      devShells = forEachSystem (pkgs: import ./shell.nix { inherit pkgs inputs; });
      formatter = forEachSystem (pkgs: pkgs.nixfmt-rfc-style);

      # NixOS configuration entrypoint
      # Available through 'nixos-rebuild --flake .#your-hostname'
      # Fresh install with disko: sudo nix run --extra-experimental-features 'nix-command flakes' 'github:nix-community/disko/latest#disko-install' -- --flake .#machine
      nixosConfigurations = {
        karkinos = lib.nixosSystem {
          modules = [ ./machines/karkinos ];
          specialArgs = { inherit inputs outputs; };
        };

        chiral = lib.nixosSystem {
          modules = [ ./machines/chiral ];
          specialArgs = { inherit inputs outputs; };
        };

        oppy = lib.nixosSystem {
          modules = [ ./machines/oppy ];
          specialArgs = { inherit inputs outputs; };
        };
      };

      # Darwin configuration entrypoint
      # Initial run: nix run --extra-experimental-features 'nix-command flakes' nix-darwin -- switch --flake .#darwin001
      # Available through 'darwin-rebuild --flake .#your-hostname'
      darwinConfigurations = {
        darwin001 = inputs.darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          modules = [ ./machines/darwin001 ];
          specialArgs = { inherit inputs outputs; };
        };
      };

      # Standalone home-manager configuration entrypoint
      # Available through 'home-manager switch --flake .#your-username@your-hostname'
      homeConfigurations = {
        "ank@karkinos" = lib.homeManagerConfiguration {
          pkgs = pkgsFor.x86_64-linux;
          extraSpecialArgs = { inherit inputs outputs; };
          # > Our main home-manager configuration file <
          modules = [

            inputs.agenix.homeManagerModules.default
            ./homes/ank/machines/karkinos.nix
          ];
        };

        "ank@oppy" = lib.homeManagerConfiguration {
          pkgs = pkgsFor.x86_64-linux;
          extraSpecialArgs = { inherit inputs outputs; };
          # > Our main home-manager configuration file <
          modules = [

            inputs.agenix.homeManagerModules.default
            ./homes/ank/machines/oppy.nix
          ];
        };

        "ngogober@oppy" = lib.homeManagerConfiguration {
          pkgs = pkgsFor.x86_64-linux;
          extraSpecialArgs = { inherit inputs outputs; };
          # > Our main home-manager configuration file <
          modules = [

            inputs.agenix.homeManagerModules.default
            ./homes/ngogober/machines/oppy.nix
          ];
        };

        "ank@chiral" = lib.homeManagerConfiguration {
          pkgs = pkgsFor.x86_64-linux;
          extraSpecialArgs = { inherit inputs outputs; };
          # > Our main home-manager configuration file <
          modules = [
            inputs.agenix.homeManagerModules.default
            ./homes/ank/machines/chiral.nix
          ];
        };
      };
    }
    // {
      # Expose custom templates
      templates = import ./templates;
    };
}
