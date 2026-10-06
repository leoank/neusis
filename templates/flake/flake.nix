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

        libList =
          [
            # Add needed packages here
            pkgs.stdenv.cc.cc
            pkgs.libGL
            pkgs.glib
          ]
          ++ pkgs.lib.optionals pkgs.stdenv.isLinux (
            with pkgs;
            [
              cudatoolkit

              # This is required for most app that uses graphics api
              # linuxPackages.nvidia_x11
            ]
          );
      in
      with pkgs;
      {
        devShells = {
          default = mkShell {
            NIX_LD = runCommand "ld.so" { } ''
              ln -s "$(cat '${pkgs.stdenv.cc}/nix-support/dynamic-linker')" $out
            '';
            NIX_LD_LIBRARY_PATH = lib.makeLibraryPath libList;
            packages = [
              # Add your packages
            ] ++ libList;
            shellHook = ''
              export LD_LIBRARY_PATH=$NIX_LD_LIBRARY_PATH:"/run/opengl-driver/lib":$LD_LIBRARY_PATH
              export CUDA_PATH=${pkgs.cudaPackages.cudatoolkit}
            '';
          };
        };
      }
    );
}
# Things one might need for debugging or adding compatibility
# export CUDA_PATH=${pkgs.cudaPackages.cudatoolkit}
# export LD_LIBRARY_PATH=${pkgs.cudaPackages.cuda_nvrtc}/lib
# export EXTRA_LDFLAGS="-L/lib -L${pkgs.linuxPackages.nvidia_x11}/lib"
# export EXTRA_CCFLAGS="-I/usr/include"
