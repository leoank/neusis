{ inputs, user, ... }:
{
  nix-homebrew = {
    inherit user;
    enable = true;
    taps = with inputs; {
      "homebrew/homebrew-core" = homebrew-core;
      "homebrew/homebrew-cask" = homebrew-cask;
      "deskflow/homebrew-tap" = deskflow-tap;
      "graelo/homebrew-tap" = pumas-tap;
      "darrylmorley/homebrew-whatcable" = whatcable-tap;
    };
    mutableTaps = false;
    autoMigrate = true;
  };
}
