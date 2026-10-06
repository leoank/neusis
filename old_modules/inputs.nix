{

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
    url = "github:nix-community/home-manager/release-25.11";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  agenix.url = "github:ryantm/agenix";
  agenix.inputs.nixpkgs.follows = "nixpkgs";

  hardware.url = "github:nixos/nixos-hardware";

  jail-nix.url = "sourcehut:~alexdavid/jail.nix";
  llm-agents.url = "github:numtide/llm-agents.nix";
  llm-agents.inputs.nixpkgs.follows = "nixpkgs-unstable";
}
