# System-level homebrew config for darwin hosts. Casks moved to
# brew-nix (via `flake.homeModules.brew-cask` + the per-user
# `hmBundles.casks` bundle). Only brews + taps + masApps remain
# here — brew-nix is cask-only, so CLI tools that don't have a
# clean nixpkgs equivalent stay on real homebrew.
{ config, ... }:
{
  homebrew = {
    enable = true;
    masApps = {
      #Xcode = 497799835;
      #"Microsoft Outlook" = 985367838;
    };
    brews = [
      "pixi"
      "gnu-sed"
      "pumas"
      "libusb"
    ];
    taps = map (key: builtins.replaceStrings [ "homebrew-" ] [ "" ] key) (
      builtins.attrNames config.nix-homebrew.taps
    );
    # Casks are managed via brew-nix in the per-user `casks`
    # hmBundle (see `homeModules/brew-cask.nix`). The list below
    # is the fallback path for casks brew-nix can't currently
    # build — retry on each `nix flake update brew-nix brew-api`.
    #
    #   * `deskflow`   — not in brew-nix's brew-api snapshot.
    #   * `fiji`       — installer-style cask, no output produced.
    #
    # (`whatsapp` used to live here too — now pulled from
    # fresh-apps.nix instead; see `users/ank/_packages.nix`.)
    casks = map (n: { name = n; greedy = true; }) [
      "deskflow"
      "fiji"
    ];
    onActivation = {
      cleanup = "uninstall";
      autoUpdate = true;
      upgrade = true;
    };
  };
}
