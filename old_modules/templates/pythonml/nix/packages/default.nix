{
  lib,
  pkgs,
  inputs,
  outputs,
  python3Packages,
  ...
}:

let
  # Apps
  packages = rec {
    your_package = python3Packages.callPackage ./your_package.nix { };

  };

in
packages
