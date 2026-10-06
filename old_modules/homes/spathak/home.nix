{ pkgs, ... }:
{
  home = {
    username = "spathak";
    homeDirectory = "/home/spathak";

    packages = with pkgs; [
      duckdb
      jq
    ];
  };
}
