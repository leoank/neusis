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
      self,
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

        libList =
          [
            # Add needed packages here
            pkgs.stdenv.cc.cc
            pkgs.libGL
            pkgs.glib
          ]
          ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
            # This is required for most app that uses graphics api
            pkgs.linuxPackages.nvidia_x11
          ];
      in
      with pkgs;
      {
        packages = pkgs.callPackage ./nix/packages {
          inherit inputs outputs;
        };
        devShells = {
          default = mkShell {
            NIX_LD = runCommand "ld.so" { } ''
              ln -s "$(cat '${pkgs.stdenv.cc}/nix-support/dynamic-linker')" $out
            '';
            NIX_LD_LIBRARY_PATH = lib.makeLibraryPath libList;
            packages = [
              cargo
              rust-analyzer
              rustfmt
              clippy
            ] ++ libList;
            venvDir = "./.venv";
            postVenvCreation = ''
              unset SOURCE_DATE_EPOCH
            '';
            postShellHook = ''
              unset SOURCE_DATE_EPOCH
            '';
            shellHook = ''
              export LD_LIBRARY_PATH=$NIX_LD_LIBRARY_PATH:$LD_LIBRARY_PATH
              export PYTHON_KEYRING_BACKEND=keyring.backends.fail.Keyring
              runHook venvShellHook
              export PYTHONPATH=${python_with_pkgs}/${python_with_pkgs.sitePackages}:$PYTHONPATH
            '';
          };
        };
      }
    );
}
