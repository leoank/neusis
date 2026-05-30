{ pkgs, ... }:
{
  home.stateVersion = "25.11";

  home.packages = with pkgs; [
    ripgrep
    fd
    jq
  ];

  programs.zsh.enable = true;
  programs.git = {
    enable = true;
    userName = "Alice Example";
    userEmail = "alice@example.org";
  };
}
