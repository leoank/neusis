{
  inputs,
  outputs,
  ...
}:
{
  config.flake.nixosModules = import ../modules/nixos/default.nix { inherit inputs outputs; };
}
