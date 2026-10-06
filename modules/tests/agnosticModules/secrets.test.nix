# Tests for flake.agnosticModules.secrets (agenix-rekey wiring) on both
# platforms. The machine imports the platform-correct agenix modules, the
# way rogue.nix / darwin001.nix do.
{ self, inputs, ... }:
{
  perSystem =
    { lib, ... }:
    let
      t = self.neusis.lib.tests;
      f = t.fixtures;

      master = {
        identity = "/Users/alice/.ssh/id_ed25519";
        pubkey = f.hostPubkey;
      };

      enabled = extra: {
        neusis.services.secrets = {
          enable = true;
          hostPubkey = f.hostPubkey;
          masterIdentities = [ master ];
        }
        // extra;
      };

      darwinWith =
        extra:
        t.evalDarwin {
          modules = [
            inputs.agenix.darwinModules.default
            inputs.agenix-rekey.darwinModules.default
            self.darwinModules.secrets
            { networking.hostName = "fixture-darwin"; }
            (enabled extra)
          ];
        };

      nixosWith =
        extra:
        t.evalNixos {
          modules = [
            f.nixosLogin
            inputs.agenix-rekey.nixosModules.default
            self.nixosModules.secrets
            { networking.hostName = "fixture"; }
            (enabled extra)
          ];
        };

      darwin = darwinWith { };
      nixos = nixosWith { rootUserPassPath = f.machines.fixture.initialHashedPassword; };

      rekeySummary = cfg: {
        hostPubkey = cfg.age.rekey.hostPubkey;
        masters = map (m: m.pubkey) cfg.age.rekey.masterIdentities;
        storageMode = cfg.age.rekey.storageMode;
        storageDir = lib.last (lib.splitString "/" (toString cfg.age.rekey.localStorageDir));
        storageParent = lib.hasSuffix "/secrets/rekeyed" (
          toString (builtins.dirOf (toString cfg.age.rekey.localStorageDir))
        );
        buildKey = {
          inherit (cfg.age.secrets.remoteBuildKey) path mode owner;
        };
      };
    in
    {
      tests.agnostic-secrets = {
        test-darwin-wires-agenix-rekey = {
          expr = rekeySummary darwin // {
            failed = t.failedAssertions darwin;
          };
          expected = {
            hostPubkey = f.hostPubkey;
            masters = [ f.hostPubkey ];
            storageMode = "local";
            storageDir = "fixture-darwin";
            storageParent = true;
            buildKey = {
              path = "/etc/nix/remote-build-key";
              mode = "0400";
              owner = "root";
            };
            failed = [ ];
          };
        };

        test-nixos-wires-agenix-rekey = {
          expr = rekeySummary nixos // {
            failed = t.failedAssertions nixos;
          };
          expected = {
            hostPubkey = f.hostPubkey;
            masters = [ f.hostPubkey ];
            storageMode = "local";
            storageDir = "fixture";
            storageParent = true;
            buildKey = {
              path = "/etc/nix/remote-build-key";
              mode = "0400";
              owner = "root";
            };
            failed = [ ];
          };
        };

        test-root-password-is-nixos-only = {
          expr = {
            nixosSecret = nixos.age.secrets ? neusis-root-pw-hash;
            nixosRoot = nixos.users.users.root.hashedPasswordFile;
            darwinIgnores =
              (darwinWith { rootUserPassPath = f.machines.fixture.initialHashedPassword; }).age.secrets
              ? neusis-root-pw-hash;
            nixosWithoutPath = (nixosWith { }).age.secrets ? neusis-root-pw-hash;
          };
          expected = {
            nixosSecret = true;
            nixosRoot = "/run/agenix/neusis-root-pw-hash";
            darwinIgnores = false;
            nixosWithoutPath = false;
          };
        };

        test-remote-build-key-can-be-opted-out = {
          expr = (darwinWith { remoteBuildKeyFile = null; }).age.secrets ? remoteBuildKey;
          expected = false;
        };

        test-storage-base-dir-is-overridable = {
          expr = toString (darwinWith { storageBaseDir = /tmp/consumer/rekeyed; }).age.rekey.localStorageDir;
          expected = "/tmp/consumer/rekeyed/fixture-darwin";
        };

        test-disabled-sets-nothing = {
          expr =
            let
              cfg = t.evalDarwin {
                modules = [
                  inputs.agenix.darwinModules.default
                  inputs.agenix-rekey.darwinModules.default
                  self.darwinModules.secrets
                ];
              };
            in
            {
              secrets = builtins.attrNames cfg.age.secrets;
              enable = cfg.neusis.services.secrets.enable;
            };
          expected = {
            secrets = [ ];
            enable = false;
          };
        };
      };
    };
}
