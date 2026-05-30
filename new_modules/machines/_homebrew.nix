{ config, ... }:
let
  mkGreedy = caskName: {
    name = caskName;
    greedy = true;
  };
in
{
  # Configure homebrew
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
    # https://github.com/nix-darwin/nix-darwin/issues/935
    # https://github.com/nix-darwin/nix-darwin/pull/1382
    # greedyCasks = true;
    casks = map mkGreedy [
      "signal"
      "whatsapp"
      "keycastr"
      "fiji"
      "hammerspoon"
      "deskflow"
      "superwhisper"
      "thaw"
      "linearmouse"
      "affinity"
      "whatcable"
    ];
    onActivation = {
      cleanup = "uninstall";
      autoUpdate = true;
      upgrade = true;
    };
  };

}
