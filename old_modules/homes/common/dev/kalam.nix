{ pkgs, outputs, ... }:
{
  home.packages = [
    outputs.packages.${pkgs.stdenv.hostPlatform.system}.kalamv2
  ];
}
