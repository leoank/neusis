{ pkgs, ... }:
{
  home = {
    username = "akalinin";
    homeDirectory = "/home/akalinin";

    packages = with pkgs; [
      duckdb
      jq
    ];
  };
}
