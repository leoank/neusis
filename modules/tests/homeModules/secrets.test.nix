# Tests for flake.homeModules.secrets: agenix-rekey for a home, with the
# rekeyed store under secrets/rekeyed/hm/<username>.
{ self, ... }:
{
  perSystem =
    { lib, testPkgs, ... }:
    let
      t = self.neusis.lib.tests;
      f = t.fixtures;
      secrets =
        extra:
        t.evalHm {
          pkgs = testPkgs;
          modules = [
            self.homeModules.secrets
            {
              neusis.service.secrets = {
                enable = true;
                userPubkey = f.hostPubkey;
                masterIdentities = [
                  {
                    identity = "/Users/alice/.ssh/id_ed25519";
                    pubkey = f.hostPubkey;
                  }
                ];
              }
              // extra;
            }
          ];
        };
      home = secrets { };
    in
    {
      tests.hm-secrets = {
        test-enable-wires-agenix-rekey-for-the-user = {
          expr = {
            hostPubkey = home.age.rekey.hostPubkey;
            masters = map (m: m.pubkey) home.age.rekey.masterIdentities;
            mode = home.age.rekey.storageMode;
            dir = lib.hasSuffix "/secrets/rekeyed/hm/alice" (toString home.age.rekey.localStorageDir);
            failed = t.failedAssertions home;
          };
          expected = {
            hostPubkey = f.hostPubkey;
            masters = [ f.hostPubkey ];
            mode = "local";
            dir = true;
            failed = [ ];
          };
        };

        test-secret-paths-resolve-under-agenix-runtime-dir = {
          expr =
            let
              cfg = secrets { } // { };
              withSecret = t.evalHm {
                pkgs = testPkgs;
                modules = [
                  self.homeModules.secrets
                  {
                    neusis.service.secrets = {
                      enable = true;
                      userPubkey = f.hostPubkey;
                      masterIdentities = [ { identity = "/Users/alice/.ssh/id_ed25519"; pubkey = f.hostPubkey; } ];
                    };
                    age.secrets.token.rekeyFile = ../_fixtures/placeholder.age;
                  }
                ];
              };
            in
            {
              names = builtins.attrNames withSecret.age.secrets;
              path = lib.hasSuffix "/token" withSecret.age.secrets.token.path;
              unused = cfg.neusis.service.secrets.enable;
            };
          expected = {
            names = [ "token" ];
            path = true;
            unused = true;
          };
        };

        # KNOWN COUPLING, pinned: importing the module without enabling it
        # does not evaluate, because the agenix-rekey home-manager module is
        # imported unconditionally and asserts `age.rekey.masterIdentities`.
        # Fix candidate: a consumer that imports this module must enable it;
        # or guard the agenix imports / set defaults under mkIf.
        test-imported-but-disabled-fails-rekey-assertion = {
          expr =
            (t.evalHm {
              pkgs = testPkgs;
              modules = [ self.homeModules.secrets ];
            }).neusis.service.secrets.enable;
          expectedError = {
            type = "ThrownError";
            msg = "rekey.masterIdentities must be set";
          };
        };
      };
    };
}
