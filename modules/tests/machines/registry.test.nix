# The registries tie machines, users and builders together; these pin
# their shape. (mkNeusisFlake over a fixture NixOS machine is covered in
# tests/lib/neusisOS.test.nix.)
{ self, ... }:
{
  perSystem =
    { lib, ... }:
    let
      r = self.neusis.registry;
      names = map (u: u.username);
    in
    {
      tests.machine-registry = {
        test-machines = {
          expr = {
            labs = builtins.attrNames r.machines;
            darwin = map (m: m.hostname) r.machines.anklab.darwin;
            nixos = map (m: m.hostname) r.machines.anklab.nixos;
            declared = builtins.attrNames self.neusis.machines;
            outputs = builtins.attrNames self.darwinConfigurations;
          };
          expected = {
            labs = [ "anklab" ];
            darwin = [
              "rogue"
              "darwin001"
            ];
            nixos = [ ];
            declared = [
              "darwin001"
              "rogue"
            ];
            outputs = [
              "darwin001"
              "rogue"
            ];
          };
        };

        test-users = {
          expr = {
            # cslab_karkinos.nix defines `cslab` too, so there is no
            # `cslab_karkinos` key (see the pinned tests below).
            labs = builtins.attrNames r.users;
            anklab = names r.users.anklab.admins;
            kumaranklab = names r.users.kumaranklab.admins;
            declared = builtins.attrNames self.neusis.users;
          };
          expected = {
            labs = [
              "all"
              "anklab"
              "cslab"
              "kumaranklab"
            ];
            anklab = [ "ank" ];
            kumaranklab = [ "kumarank" ];
            declared = [
              "ank"
              "kumarank"
            ];
          };
        };

        # KNOWN BUG, pinned: registry/users/all.nix reads `self.registry.users.*`
        # and `self.lib.neusisOS`, which live under `self.neusis.*` since the
        # schema moved. Nothing live uses `all`, so it only fails when read.
        test-all-registry-uses-stale-self-paths = {
          expr = names r.users.all.admins;
          expectedError = {
            type = "EvalError";
            msg = "attribute 'lib' missing";
          };
        };

        # KNOWN BUG, pinned: registry/users/cslab.nix and cslab_karkinos.nix
        # both define `cslab` from `self.users.ank.neusisOS` (should be
        # `self.neusis.users.ank.neusisOS`), so the merged list has two broken
        # entries and `cslab_karkinos` is never declared.
        test-cslab-registries-use-stale-self-paths = {
          expr = names r.users.cslab.admins;
          expectedError = {
            type = "EvalError";
            msg = "attribute 'users' missing";
          };
        };

        test-builders-mirror-the-machines = {
          expr = map (b: {
            inherit (b) hostName systems hostPubkey;
          }) r.builders.anklab;
          expected = map (m: {
            inherit (m) hostPubkey;
            hostName = m.hostname;
            systems = [ m.system ];
          }) r.machines.anklab.darwin;
        };

        test-every-user-has-bundles-for-their-hosts = {
          expr = {
            ank = builtins.attrNames self.neusis.users.ank.neusisOS.machineToBundlesMap;
            kumarank = builtins.attrNames self.neusis.users.kumarank.neusisOS.machineToBundlesMap;
          };
          expected = {
            ank = [ "rogue" ];
            kumarank = [ "darwin001" ];
          };
        };
      };
    };
}
