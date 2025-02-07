{ pkgs, ... }:
{
  home = {
    username = "rshen";
    homeDirectory = "/home/rshen";

    packages = with pkgs; [
      duckdb
      jq
    ];
  };
}
