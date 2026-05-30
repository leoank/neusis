{ inputs, lib, ... }:
{
  imports = [
    # Add support for dendritic pattern
    # This add all thing needed to configure flake file for dendritic pattern
    # look here for more info: https://github.com/denful/flake-file/tree/main/modules/dendritic
    inputs.flake-file.flakeModules.dendritic
  ];

  flake-file.inputs = {
    # Nixpkgs
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-file.url = lib.mkDefault "github:vic/flake-file";
  };

  # generate the flake output string
  # This way you can use custom modules directory
  flake-file.outputs = ''
    inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./new_modules)
  '';

}
