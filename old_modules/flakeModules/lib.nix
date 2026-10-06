{
  lib,
  inputs,
  ...
}:
{
  config.flake.lib = import ../lib { inherit lib inputs; };
}
