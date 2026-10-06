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
            labs = builtins.attrNames r.users;
            anklab = names r.users.anklab.admins;
            kumaranklab = names r.users.kumaranklab.admins;
            cslab = names r.users.cslab.admins;
            cslab_karkinos = names r.users.cslab_karkinos.admins;
            declared = builtins.attrNames self.neusis.users;
          };
          expected = {
            labs = [
              "all"
              "anklab"
              "cslab"
              "cslab_karkinos"
              "kumaranklab"
            ];
            anklab = [ "ank" ];
            kumaranklab = [ "kumarank" ];
            cslab = [ "ank" ];
            cslab_karkinos = [ "ank" ];
            declared = [
              "ank"
              "kumarank"
            ];
          };
        };

        # `all` is the per-role merge of every lab (cslab, cslab_karkinos,
        # anklab, kumaranklab — in that order).
        test-all-merges-every-lab = {
          expr = lib.mapAttrs (_: names) r.users.all;
          expected = {
            admins = [
              "ank"
              "ank"
              "ank"
              "kumarank"
            ];
            regulars = [ ];
            guests = [ ];
            locked = [ ];
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
