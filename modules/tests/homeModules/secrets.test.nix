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

        # Importing the module means enabling it (it loads agenix-rekey,
        # which must be configured), so `enable` defaults to true …
        test-import-enables-by-default = {
          expr =
            let
              cfg = t.evalHm {
                pkgs = testPkgs;
                modules = [
                  self.homeModules.secrets
                  {
                    neusis.service.secrets.userPubkey = f.hostPubkey;
                    neusis.service.secrets.masterIdentities = [
                      {
                        identity = "/Users/alice/.ssh/id_ed25519";
                        pubkey = f.hostPubkey;
                      }
                    ];
                  }
                ];
              };
            in
            {
              enable = cfg.neusis.service.secrets.enable;
              wired = cfg.age.rekey.hostPubkey == f.hostPubkey;
              failed = t.failedAssertions cfg;
            };
          expected = {
            enable = true;
            wired = true;
            failed = [ ];
          };
        };

        # … and switching it off is rejected with our own message rather
        # than agenix-rekey's.
        test-disabling-after-import-is-rejected = {
          expr = (secrets { enable = false; }).age.rekey.storageMode;
          expectedError = {
            type = "ThrownError";
            msg = "cannot be disabled once imported";
          };
        };
      };
    };
}
