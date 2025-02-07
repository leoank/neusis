{ pkgs, ... }:
{
  home = {
    username = "jewald";
    homeDirectory = "/home/jewald";

    packages = with pkgs; [
      duckdb
      jq
    ];
  };
}
