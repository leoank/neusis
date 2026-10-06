{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:
let
  gc_freq =
    if pkgs.stdenv.isDarwin then
      {
        interval = {
          Weekday = 0;
          Hour = 0;
          Minute = 0;
        };
      }
    else
      {
        dates = "weekly";
      };
in
{
  nix = {
    package = pkgs.nix;
    gc = {
      automatic = true;
      options = "--delete-older-than 15d";
    } // gc_freq;

    # Deduplicate and optimize nix store
    optimise.automatic = true;

    # Turn this on to make command line easier
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  # This will add each flake input as a registry
  # To make nix3 commands consistent with your flake
  nix.registry = (lib.mapAttrs (_: flake: { inherit flake; })) (
    (lib.filterAttrs (_: lib.isType "flake")) inputs
  );

  # This will additionally add your inputs to the system's legacy channels
  # Making legacy nix commands consistent as well, awesome!
  nix.nixPath = [ "/etc/nix/path" ];
  environment.etc = lib.mapAttrs' (name: value: {
    name = "nix/path/${name}";
    value.source = value.flake;
  }) config.nix.registry;
}
