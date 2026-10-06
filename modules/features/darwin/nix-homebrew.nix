{ ... }:

{
  flake-file.inputs = {
    nix-homebrew = {
      url = "github:zhaofengli-wip/nix-homebrew";
    };
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
    # taps
    deskflow-tap = {
      url = "github:deskflow/homebrew-tap";
      flake = false;
    };
    pumas-tap = {
      url = "github:graelo/homebrew-tap";
      flake = false;
    };
    whatcable-tap = {
      url = "github:darrylmorley/homebrew-whatcable";
      flake = false;
    };
  };
  flake.neusis.features.darwin.nix-homebrew =

    { config, inputs, ... }:
    {
      imports = [
        inputs.nix-homebrew.darwinModules.nix-homebrew
      ];
      nix-homebrew = {
        user = config.system.primaryUser;
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
    };
}
