# Shell for bootstrapping flake-enabled nix and other tooling
{
  pkgs ?
    # If pkgs is not defined, instantiate nixpkgs from locked commit
    let
      lock = (builtins.fromJSON (builtins.readFile ./flake.lock)).nodes.nixpkgs.locked;
      nixpkgs = fetchTarball {
        url = "https://github.com/nixos/nixpkgs/archive/${lock.rev}.tar.gz";
        sha256 = lock.narHash;
      };
    in
    import nixpkgs { overlays = [ ]; },
  inputs,
  ...
}:
{
  default = pkgs.mkShell {
    NIX_CONFIG = "extra-experimental-features = nix-command flakes";
    nativeBuildInputs = with pkgs; [
      nix
      home-manager
      git
      uv

      inputs.agenix.packages.${system}.default
      ssh-to-age
      gnupg
      age

      # Documentation tools
      markdownlint-cli
    ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
      # Linux-only tools for NixOS deployment
      disko
      nixos-anywhere
    ];
  };
}
