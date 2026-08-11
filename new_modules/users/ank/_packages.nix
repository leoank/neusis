{
  pkgs,
  inputs,
  ...
}:
{
  home.packages =
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
      # Signal + WhatsApp from fresh-apps.nix (daily upstream builds)
      # instead of homebrew casks. See features/flake/fresh-apps.nix.
      inputs.fresh-apps.packages.${pkgs.stdenv.hostPlatform.system}.signal-desktop
      inputs.fresh-apps.packages.${pkgs.stdenv.hostPlatform.system}.whatsapp
      spotify
      pkgs.unstable.obsidian
      # broken right now. uncomment later
      #pkgs.unstable.blender
    ];
}
