{ pkgs, ... }:
{
  home = {
    username = "shsingh";
    homeDirectory = "/home/shsingh";

    packages = with pkgs; [
      duckdb
      jq
    ];
  };
}
