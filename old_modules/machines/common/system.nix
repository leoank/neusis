{
  pkgs,
  outputs,
  ...
}:
{
  # FHS compatibility
  programs.nix-ld.enable = true;

  # Required to make theme related things work
  programs.dconf.enable = true;

  nixpkgs = {
    overlays = builtins.attrValues outputs.overlays;
    config = {
      allowUnfree = true;
    };
  };

  # Base system packages shared across all machines
  environment.systemPackages = with pkgs; [
    vim
    dive
    podman-tui
  ];

  # Ensure terminfo entries for modern terminals (ghostty, kitty, etc.)
  # are available so SSH sessions from these terminals work correctly
  environment.enableAllTerminfo = true;

  environment.shells = [ pkgs.zsh ];
  programs.zsh.enable = true;
  programs.fish.enable = true;
}
