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
      anklab = mesh [ self.neusis.features.agnostic.anklab_mesh ];
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
            # OAuth client = the shared one under secrets/common/.
            oauth = map (n: baseNameOf cslab.age.secrets.${n}.rekeyFile) [
              "tsClientIdCslab"
              "tsClientSecretCslab"
            ];
            failed = t.failedAssertions cslab;
          };
          expected = {
            default = "cslab";
            org = "shntnu.github";
            authKey = "/run/agenix/tsAuthKeyCslab";
            secret = true;
            oauth = [
              "tsclient.age"
              "tssecret.age"
            ];
            failed = [ ];
          };
        };

        # anklab_mesh: one profile per tailnet, its three secrets from secrets/anklab/
        # named <profile>Ts<Kind>; the API calls use the credential's own tailnet ("-");
        # runxi is the default.
        test-anklab-mesh-profiles-from-anklab-secrets = {
          expr =
            let
              p = (ts anklab).profiles.runxi;
              names = [
                "runxi"
                "leoank"
                "shntnu"
              ];
            in
            {
              enabled = (ts anklab).enable;
              default = (ts anklab).defaultProfile;
              profiles = builtins.attrNames (ts anklab).profiles;
              secrets = lib.mapAttrs (
                _: s: lib.removePrefix (toString ../../../secrets + "/") (toString s.rekeyFile)
              ) anklab.age.secrets;
              files = lib.genAttrs names (n: [
                (ts anklab).profiles.${n}.authKeyFile
                (ts anklab).profiles.${n}.clientIdFile
                (ts anklab).profiles.${n}.clientSecretFile
              ]);
              orgs = lib.unique (lib.mapAttrsToList (_: q: q.tailnetOrg) (ts anklab).profiles);
              # every tailnet's subnet routes are accepted, its DNS kept
              acceptRoutes = lib.mapAttrs (_: q: q.acceptRoutes) (ts anklab).profiles;
              acceptDns = lib.unique (lib.mapAttrsToList (_: q: q.acceptDns) (ts anklab).profiles);
              hostName = p.hostName;
              forceHostName = p.forceHostName;
              disableKeyExpiry = p.disableKeyExpiry;
              scripts = lib.filter (lib.hasPrefix "neusis-ts-") (t.pkgNames anklab.environment.systemPackages);
              failed = t.failedAssertions anklab;
            };
          expected = {
            enabled = true;
            default = "runxi";
            profiles = [
              "leoank"
              "runxi"
              "shntnu"
            ];
            # the scripts use the devices:core clients where a tailnet has one
            secrets = {
              runxiTsAuthKey = "anklab/runxiTsAuthKey.age";
              runxiDeviceTsClientId = "anklab/runxiDeviceTsClientId.age";
              runxiDeviceTsClientSecret = "anklab/runxiDeviceTsClientSecret.age";
              leoankTsAuthKey = "anklab/leoankTsAuthKey.age";
              leoankDeviceTsClientId = "anklab/leoankDeviceTsClientId.age";
              leoankDeviceTsClientSecret = "anklab/leoankDeviceTsClientSecret.age";
              shntnuTsAuthKey = "anklab/shntnuTsAuthKey.age";
              shntnuTsClientId = "anklab/shntnuTsClientId.age";
              shntnuTsClientSecret = "anklab/shntnuTsClientSecret.age";
            };
            files = {
              runxi = [
                "/run/agenix/runxiTsAuthKey"
                "/run/agenix/runxiDeviceTsClientId"
                "/run/agenix/runxiDeviceTsClientSecret"
              ];
              leoank = [
                "/run/agenix/leoankTsAuthKey"
                "/run/agenix/leoankDeviceTsClientId"
                "/run/agenix/leoankDeviceTsClientSecret"
              ];
              shntnu = [
                "/run/agenix/shntnuTsAuthKey"
                "/run/agenix/shntnuTsClientId"
                "/run/agenix/shntnuTsClientSecret"
              ];
            };
            orgs = [ "-" ];
            acceptRoutes = {
              runxi = true;
              leoank = true;
              shntnu = true;
            };
            acceptDns = [ true ];
            hostName = "fixture-darwin";
            forceHostName = true;
            disableKeyExpiry = true;
            scripts = [
              "neusis-ts-leoank"
              "neusis-ts-runxi"
              "neusis-ts-shntnu"
            ];
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
