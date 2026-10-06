# This file defines the neusis lib public API.

{
  lib,
  inputs,
  ...
}:
{
  neusisOS = import ./neusisOS.nix { inherit lib inputs; };
  utils = import ./utils { inherit lib; };
}
