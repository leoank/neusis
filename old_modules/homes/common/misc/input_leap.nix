{
  inputs,
  pkgs,
  ...
}:
let
  unstable = import inputs.nixpkgs-unstable { system = pkgs.stdenv.hostPlatform.system; };
in
{
  home.packages = [ pkgs.input-leap ];
}
