# Tests for flake.neusis.features.agnostic.ank_mesh and cslab_mesh: the
# two tailscale profile features, alone and together. Composed with the
# tailscale module + secrets the way the machines do.
{ self, inputs, ... }:
{
  perSystem =
    { lib, ... }:
    let
      t = self.neusis.lib.tests;
      f = t.fixtures;

      base = [
        inputs.agenix.darwinModules.default
        inputs.agenix-rekey.darwinModules.default
        self.darwinModules.secrets
        self.darwinModules.tailscale
        {
          networking.hostName = "fixture-darwin";
          neusis.services.secrets = {
            enable = true;
            hostPubkey = f.hostPubkey;
            masterIdentities = [
              {
                identity = "/Users/alice/.ssh/id_ed25519";
                pubkey = f.hostPubkey;
              }
            ];
          };
        }
      ];

      mesh = features: t.evalDarwin { modules = base ++ features; };
      ank = mesh [ self.neusis.features.agnostic.ank_mesh ];
      cslab = mesh [ self.neusis.features.agnostic.cslab_mesh ];
      both = mesh [
        self.neusis.features.agnostic.ank_mesh
        self.neusis.features.agnostic.cslab_mesh
      ];
      ts = cfg: cfg.neusis.services.tailscale;
    in
    {
      tests.feature-mesh = {
        test-ank-mesh-leoank-profile-with-oauth-claims = {
          expr =
            let
              p = (ts ank).profiles.leoank;
            in
            {
              enabled = (ts ank).enable;
              default = (ts ank).defaultProfile;
              secrets = lib.sort lib.lessThan (builtins.attrNames ank.age.secrets);
              authKey = p.authKeyFile;
              hostName = p.hostName;
              forceHostName = p.forceHostName;
              disableKeyExpiry = p.disableKeyExpiry;
              org = p.tailnetOrg;
              daemon = ank.launchd.daemons ? neusis-tailscale-autoconnect;
              failed = t.failedAssertions ank;
            };
          expected = {
            enabled = true;
            default = "leoank";
            secrets = [
              "remoteBuildKey"
              "tsAuthKeyLeoank"
              "tsClientId"
              "tsClientSecret"
            ];
            authKey = "/run/agenix/tsAuthKeyLeoank";
            hostName = "fixture-darwin";
            forceHostName = true;
            disableKeyExpiry = true;
            org = "leoank.github";
            daemon = true;
            failed = [ ];
          };
        };

        test-cslab-mesh-alone-defaults-to-cslab = {
          expr = {
            default = (ts cslab).defaultProfile;
            org = (ts cslab).profiles.cslab.tailnetOrg;
            authKey = (ts cslab).profiles.cslab.authKeyFile;
            secret = cslab.age.secrets ? tsAuthKeyCslab;
            failed = t.failedAssertions cslab;
          };
          expected = {
            default = "cslab";
            org = "shntnu.github";
            authKey = "/run/agenix/tsAuthKeyCslab";
            secret = true;
            failed = [ ];
          };
        };

        test-both-meshes-keep-leoank-as-default = {
          expr = {
            default = (ts both).defaultProfile;
            profiles = builtins.attrNames (ts both).profiles;
            scripts = lib.filter (lib.hasPrefix "neusis-ts-") (t.pkgNames both.environment.systemPackages);
            failed = t.failedAssertions both;
          };
          expected = {
            default = "leoank";
            profiles = [
              "cslab"
              "leoank"
            ];
            scripts = [
              "neusis-ts-cslab"
              "neusis-ts-leoank"
            ];
            failed = [ ];
          };
        };
      };
    };
}
