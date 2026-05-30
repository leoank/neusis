{ self, ... }:
{
  flake.neusis.features.agnostic.nix-settings =
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
        }
        // gc_freq;

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

      # Add nix substituters
      nix.settings = {
        trusted-users = lib.mkIf pkgs.stdenv.isDarwin [
          "@admin"
          config.system.primaryUser
        ];
        substituters = [
          "https://cache.flox.dev"
          "https://nix-community.cachix.org"
          "https://devenv.cachix.org"
          "https://nix-gaming.cachix.org"
          "https://ai.cachix.org"
          "https://numtide.cachix.org"
          "https://cache.numtide.com"

        ];
        trusted-public-keys = [
          "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs="
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
          "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
          "ai.cachix.org-1:N9dzRK+alWwoKXQlnn0H6aUx0lU/mspIoz8hMvGvbbc="
          "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
          "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
        ];
      };

    };
}
