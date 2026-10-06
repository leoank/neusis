# Tests for flake.agnosticModules.hm-system-init: it turns user registries
# into `home-manager.users.<name>` entries from each user's
# machineToBundlesMap.<hostname>, on NixOS and nix-darwin alike.
{ self, inputs, ... }:
{
  perSystem =
    { lib, ... }:
    let
      t = self.neusis.lib.tests;
      f = t.fixtures;
      os = self.neusis.lib.neusisOS;

      init = extra: {
        neusis.services.hm-system-init = {
          enable = true;
          userRegistries = [ f.lab ];
        }
        // extra;
      };

      darwinModules = extra: [
        inputs.home-manager.darwinModules.home-manager
        self.darwinModules.hm-system-init
        (os.mkAdmin f.alice)
        (os.mkRegular f.bob)
        { networking.hostName = "fixture-darwin"; }
        (init extra)
      ];

      nixosModules = extra: [
        inputs.home-manager.nixosModules.home-manager
        self.nixosModules.hm-system-init
        f.nixosLogin
        { age.secrets.commonInitialHashedPassword.file = f.machines.fixture.initialHashedPassword; }
        (os.mkAdmin f.alice)
        (os.mkRegular f.bob)
        { networking.hostName = "fixture"; }
        (init extra)
      ];

      darwin = t.evalDarwin { modules = darwinModules { }; };
      nixos = t.evalNixos { modules = nixosModules { }; };

      summary = cfg: {
        users = builtins.attrNames cfg.home-manager.users;
        aliceHasHello = t.hasPkg "hello" cfg.home-manager.users.alice.home.packages;
        stateVersion = cfg.home-manager.users.alice.home.stateVersion;
        useGlobalPkgs = cfg.home-manager.useGlobalPkgs;
        # home-manager adds its own nixosConfig/darwinConfig; neusis adds these two
        specialArgs = lib.all (a: cfg.home-manager.extraSpecialArgs ? ${a}) [ "inputs" "outputs" ];
        failed = t.failedAssertions cfg;
      };

      expectedSummary = {
        # alice maps bundles to this host, bob maps nothing
        users = [ "alice" ];
        aliceHasHello = true;
        stateVersion = "25.11";
        useGlobalPkgs = false;
        specialArgs = true;
        failed = [ ];
      };
    in
    {
      tests.agnostic-hm-system-init = {
        test-darwin-wires-users-from-bundles-map = {
          expr = summary darwin;
          expected = expectedSummary;
        };

        test-nixos-wires-users-from-bundles-map = {
          expr = summary nixos;
          expected = expectedSummary;
        };

        test-default-state-version-is-overridable = {
          expr =
            (t.evalNixos { modules = nixosModules { defaultStateVersion = "24.11"; }; })
            .home-manager.users.alice.home.stateVersion;
          expected = "24.11";
        };

        test-bundle-may-override-state-version = {
          expr =
            (t.evalDarwin {
              modules = darwinModules { } ++ [
                { home-manager.users.alice.home.stateVersion = "23.11"; }
              ];
            }).home-manager.users.alice.home.stateVersion;
          expected = "23.11";
        };

        test-unknown-host-maps-nobody = {
          expr =
            (t.evalDarwin {
              modules = darwinModules { } ++ [
                { networking.hostName = lib.mkForce "elsewhere"; }
              ];
            }).home-manager.users;
          expected = { };
        };

        test-disabled-wires-nobody = {
          expr =
            (t.evalDarwin {
              modules = darwinModules { enable = false; };
            }).home-manager.users;
          expected = { };
        };
      };
    };
}
