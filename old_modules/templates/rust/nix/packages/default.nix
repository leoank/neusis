{
  lib,
  pkgs,
  inputs,
  outputs,
  ...
}:

let
  # Apps
  packages = rec {
    your_package = pkgs.callPackage ./your_package.nix { };

  };

in
packages
