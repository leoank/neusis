# Tests for the `flake.neusis` schema (modules/lib/neusis-options.nix),
# evaluated the way a consumer would: a fresh flake-parts evaluation that
# imports only the options module.
{ self, inputs, ... }:
{
  perSystem =
    { lib, ... }:
    let
      f = self.neusis.lib.tests.fixtures;

      # Evaluate the options module plus `modules`; return `flake.neusis`.
      evalOptions =
        modules:
        (inputs.flake-parts.lib.evalFlakeModule { inherit inputs; } {
          imports = [ ../../lib/neusis-options.nix ] ++ modules;
          systems = [ ];
        }).config.flake;

      basic = evalOptions [
        {
          flake.neusis.users.alice.neusisOS.fullName = "Alice Fixture";
          flake.neusis.machines.box.hostPubkey = f.hostPubkey;
        }
      ];
    in
    {
      tests.lib-neusis-options = {
        test-user-defaults = {
          expr = {
            inherit (basic.neusis.users.alice.neusisOS)
              username
              shell
              sshKeys
              machineToBundlesMap
              ;
            bundles = basic.neusis.users.alice.hmBundles;
          };
          expected = {
            username = "alice";
            shell = "bash";
            sshKeys = [ ];
            machineToBundlesMap = { };
            bundles = { };
          };
        };

        test-user-fields-merge-across-modules = {
          expr =
            let
              merged = evalOptions [
                { flake.neusis.users.alice.neusisOS.fullName = "Alice Fixture"; }
                { flake.neusis.users.alice.neusisOS.shell = "zsh"; }
                { flake.neusis.users.alice.hmBundles.a = { }; }
                { flake.neusis.users.alice.hmBundles.b = { }; }
              ];
            in
            {
              inherit (merged.neusis.users.alice.neusisOS) fullName shell;
              bundles = builtins.attrNames merged.neusis.users.alice.hmBundles;
            };
          expected = {
            fullName = "Alice Fixture";
            shell = "zsh";
            bundles = [
              "a"
              "b"
            ];
          };
        };

        test-machine-defaults = {
          expr = {
            inherit (basic.neusis.machines.box)
              hostname
              computerName
              system
              nixpkgs
              primaryUser
              modulesSpecialArgs
              userRegistries
              initialHashedPassword
              ;
          };
          expected = {
            hostname = "box";
            computerName = null;
            system = "x86_64-linux";
            nixpkgs = null;
            primaryUser = null;
            modulesSpecialArgs = { };
            userRegistries = [ ];
            initialHashedPassword = null;
          };
        };

        test-machine-host-pubkey-is-required = {
          expr = (evalOptions [ { flake.neusis.machines.box = { }; } ]).neusis.machines.box.hostPubkey;
          expectedError = {
            type = "ThrownError";
            msg = "hostPubkey";
          };
        };

        test-machine-system-must-be-a-string = {
          expr =
            (evalOptions [
              {
                flake.neusis.machines.box = {
                  hostPubkey = f.hostPubkey;
                  system = 42;
                };
              }
            ]).neusis.machines.box.system;
          expectedError = {
            type = "ThrownError";
            msg = "not of type";
          };
        };

        # Regression: registry role lists are `listOf attrs`, so user
        # metadata passes through verbatim (a `deferredModule` typing
        # used to wrap each entry and hide `username`).
        test-registry-users-pass-through-verbatim = {
          expr =
            let
              r = (evalOptions [ { flake.neusis.registry.users.lab = f.lab; } ]).neusis.registry.users.lab;
            in
            {
              admins = map (u: u.username) r.admins;
              regulars = map (u: u.username) r.regulars;
              guests = r.guests;
              locked = r.locked;
            };
          expected = {
            admins = [ "alice" ];
            regulars = [ "bob" ];
            guests = [ ];
            locked = [ ];
          };
        };

        test-registry-machines-accept-machine-values = {
          expr =
            let
              r =
                (evalOptions [
                  {
                    flake.neusis.machines.box.hostPubkey = f.hostPubkey;
                    flake.neusis.registry.machines.lab = {
                      nixos = [ f.machines.fixture ];
                      darwin = [ f.machines.fixture-darwin ];
                    };
                  }
                ]).neusis.registry.machines.lab;
            in
            {
              nixos = map (m: m.hostname) r.nixos;
              darwin = map (m: "${m.hostname}/${m.computerName}") r.darwin;
            };
          expected = {
            nixos = [ "fixture" ];
            darwin = [ "fixture-darwin/Fixture Mac" ];
          };
        };

        test-feature-namespaces = {
          expr =
            let
              n = (evalOptions [ { flake.neusis.features.hm.foo = { }; } ]).neusis.features;
            in
            {
              namespaces = builtins.attrNames n;
              hm = builtins.attrNames n.hm;
            };
          expected = {
            namespaces = [
              "agnostic"
              "darwin"
              "flake"
              "hm"
              "nixos"
            ];
            hm = [ "foo" ];
          };
        };

        test-lib-namespaces-are-raw = {
          expr = (evalOptions [ { flake.neusis.lib.foo.bar = 1; } ]).neusis.lib.foo;
          expected = {
            bar = 1;
          };
        };

        test-agnostic-modules-option-exists = {
          expr = builtins.attrNames (evalOptions [ { flake.agnosticModules.foo = { }; } ]).agnosticModules;
          expected = [ "foo" ];
        };

        test-registry-builders-are-lists-of-attrs = {
          expr = map (b: b.hostName) (
            (evalOptions [ { flake.neusis.registry.builders.lab = f.builders; } ]).neusis.registry.builders.lab
          );
          expected = [
            "fixture"
            "other-builder"
          ];
        };
      };
    };
}
