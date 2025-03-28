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

        fhsenv = pkgs.buildFHSEnv {
          name = "fhs-shell";
          targetPkgs =
            pkgs: with pkgs; [
              gcc
              cudatoolkit
              libGL
              libz
              mpkgs.uv
              python311
            ];
          profile = ''
            export VENVDIR=.venv
            if [[ -d "$VENVDIR" ]]; then
              printf "%s\n" "Skipping venv creation, '$VENVDIR' already exists"
              source "$VENVDIR/bin/activate"
            else
              printf "%s\n" "Creating new venv environment in path: '$VENVDIR'"
              python -m venv "$VENVDIR"
              source "$VENVDIR/bin/activate"
            fi
          '';
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
# Things one might need for debugging or adding compatibility
# export CUDA_PATH=${pkgs.cudaPackages.cudatoolkit}
# export LD_LIBRARY_PATH=${pkgs.cudaPackages.cuda_nvrtc}/lib
# export EXTRA_LDFLAGS="-L/lib -L${pkgs.linuxPackages.nvidia_x11}/lib"
# export EXTRA_CCFLAGS="-I/usr/include"

# Data syncthing commands
# syncthing cli show system | jq .myID
# syncthing cli config devices add --device-id $DEVICE_ID_B
# syncthing cli config folders $FOLDER_ID devices add --device-id $DEVICE_ID_B
# syncthing cli config devices $DEVICE_ID_A auto-accept-folders set true

# FHS related help
# https://discourse.nixos.org/t/best-way-to-define-common-fhs-environment/25930
# https://ryantm.github.io/nixpkgs/builders/special/fhs-environments/
