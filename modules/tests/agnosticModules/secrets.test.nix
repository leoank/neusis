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

      # A consumer's minimal setup: its own key, master identity and storage dir.
      enabled = extra: {
        neusis.services.secrets = {
          enable = true;
          hostPubkey = f.hostPubkey;
          masterIdentities = [ master ];
          storageBaseDir = /tmp/consumer/rekeyed;
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
        storageDir = toString cfg.age.rekey.localStorageDir;
        # None of neusis's own secrets unless named (its build key comes with the
        # distributed-builds feature).
        buildKey = cfg.age.secrets ? remoteBuildKey;
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
            storageDir = "/tmp/consumer/rekeyed/fixture-darwin";
            buildKey = false;
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
            storageDir = "/tmp/consumer/rekeyed/fixture";
            buildKey = false;
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

        test-remote-build-key-only-when-named = {
          expr =
            let
              key = (darwinWith { remoteBuildKeyFile = f.machines.fixture.initialHashedPassword; }).age.secrets.remoteBuildKey;
            in
            {
              rekeyFile = key.rekeyFile;
              inherit (key) path mode owner;
            };
          expected = {
            rekeyFile = f.machines.fixture.initialHashedPassword;
            path = "/etc/nix/remote-build-key";
            mode = "0400";
            owner = "root";
          };
        };

        # No default storage dir: one would point into neusis's own source.
        test-storage-base-dir-has-no-default = {
          expr = toString
            (t.evalDarwin {
              modules = [
                inputs.agenix.darwinModules.default
                inputs.agenix-rekey.darwinModules.default
                self.darwinModules.secrets
                { networking.hostName = "fixture-darwin"; }
                {
                  neusis.services.secrets = {
                    enable = true;
                    hostPubkey = f.hostPubkey;
                    masterIdentities = [ master ];
                  };
                }
              ];
            }).age.rekey.localStorageDir;
          expectedError = {
            type = "ThrownError";
            msg = "storageBaseDir";
          };
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
