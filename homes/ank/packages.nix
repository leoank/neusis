{
  pkgs,
  inputs,
  outputs,
  ...
}:
with pkgs;
[
  duckdb
  jq
  pkgs.unstable.mpv
  nix-output-monitor
  nix-fast-build
  nh
  comma
  manix
  nix-index
  nix-diff
  nix-du
  nix-melt
  nix-tree
  nix-init
  nvd
  nurl
  statix
  bat
  eza
  glances
  gping
  procs
  bandwhich
  inputs.msgvault.packages.${pkgs.stdenv.hostPlatform.system}.default
  bitwarden-desktop
  pnpm
  mosh
  rmpc
]
++ pkgs.lib.optionals pkgs.stdenv.isLinux [
  extra-container
  nixos-shell
  quickemu
  nixos-generators
]
++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
  # goes out of date very quickly
  # pkgs.master.signal-desktop-bin
  # pkgs.master.whatsapp-for-mac
  spotify
  pkgs.unstable.obsidian
  # broken right now. uncomment later
  #pkgs.unstable.blender
]
