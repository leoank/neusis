# Tests for flake.neusis.features.agnostic.nix-settings on both platforms.
{ self, inputs, ... }:
{
  perSystem =
    { lib, ... }:
    let
      t = self.neusis.lib.tests;
      feature = self.neusis.features.agnostic.nix-settings;
      darwin = t.evalDarwin { modules = [ feature ]; };
      nixos = t.evalNixos { modules = [ feature ]; };

      common = cfg: {
        gcAutomatic = cfg.nix.gc.automatic;
        gcOptions = cfg.nix.gc.options;
        optimise = cfg.nix.optimise.automatic;
        flakes = lib.hasInfix "experimental-features = nix-command flakes" cfg.nix.extraOptions;
        # nixpkgs appends cache.nixos.org and its key on both platforms
        substituters = lib.all (s: builtins.elem s cfg.nix.settings.substituters) [
          "https://cache.flox.dev"
          "https://nix-community.cachix.org"
          "https://devenv.cachix.org"
          "https://nix-gaming.cachix.org"
          "https://ai.cachix.org"
          "https://numtide.cachix.org"
          "https://cache.numtide.com"
        ];
        keys = builtins.length cfg.nix.settings.trusted-public-keys == builtins.length cfg.nix.settings.substituters;
        community = lib.any (lib.hasPrefix "nix-community.cachix.org-1:") cfg.nix.settings.trusted-public-keys;
        nixPath = cfg.nix.nixPath;
        registryHasInputs = lib.all (n: cfg.nix.registry ? ${n}) [
          "nixpkgs"
          "home-manager"
          "darwin"
        ];
        etcNixpkgs = cfg.environment.etc ? "nix/path/nixpkgs";
        failed = t.failedAssertions cfg;
      };
      expectedCommon = {
        gcAutomatic = true;
        gcOptions = "--delete-older-than 15d";
        optimise = true;
        flakes = true;
        substituters = true;
        keys = true;
        community = true;
        nixPath = [ "/etc/nix/path" ];
        registryHasInputs = true;
        etcNixpkgs = true;
        failed = [ ];
      };
    in
    {
      tests.feature-nix-settings = {
        test-darwin-weekly-gc-and-trusted-admins = {
          expr = common darwin // {
            gcInterval = {
              inherit (darwin.nix.gc.interval) Weekday Hour Minute;
            };
            # nix-darwin adds root itself
            trusted = darwin.nix.settings.trusted-users;
          };
          expected = expectedCommon // {
            gcInterval = {
              Weekday = 0;
              Hour = 0;
              Minute = 0;
            };
            trusted = [
              "root"
              "@admin"
              "alice"
            ];
          };
        };

        test-nixos-weekly-gc = {
          expr = common nixos // {
            gcDates = nixos.nix.gc.dates;
            # trusted-users is Darwin-only here; NixOS keeps its default
            trustedDefault = nixos.nix.settings.trusted-users;
          };
          expected = expectedCommon // {
            gcDates = [ "weekly" ];
            trustedDefault = [ "root" ];
          };
        };

        test-registry-pins-every-flake-input = {
          expr =
            let
              flakeInputs = builtins.attrNames (lib.filterAttrs (_: lib.isType "flake") inputs);
            in
            lib.sort lib.lessThan (builtins.attrNames nixos.nix.registry) == lib.sort lib.lessThan flakeInputs;
          expected = true;
        };
      };
    };
}
