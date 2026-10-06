# Consumer smoke test for the public API: a fresh flake-parts evaluation
# imports `self.flakeModules.default` (as a downstream repo would), declares
# a user, a registry and a NixOS machine, and builds outputs through
# `flake.neusis.lib.neusisOS.mkNeusisFlake`.
{ self, inputs, ... }:
{
  perSystem =
    { lib, ... }:
    let
      f = self.neusis.lib.tests.fixtures;

      consumer =
        (inputs.flake-parts.lib.evalFlakeModule { inherit inputs; } (
          { config, ... }:
          let
            n = config.flake.neusis;
          in
          {
            imports = [ self.flakeModules.default ];
            systems = [ ];

            flake.neusis.users.alice.neusisOS = {
              fullName = "Alice Consumer";
              shell = "zsh";
              machineToBundlesMap.box = [ f.aliceBundle ];
            };
            flake.neusis.registry.users.lab.admins = [ n.users.alice.neusisOS ];
            flake.neusis.machines.box = {
              system = "x86_64-linux";
              hostPubkey = f.hostPubkey;
              userRegistries = [ n.registry.users.lab ];
              initialHashedPassword = f.machines.fixture.initialHashedPassword;
              module = f.nixosLogin;
            };
            flake.neusis.registry.machines.lab.nixos = [ n.machines.box ];

            flake.nixosConfigurations =
              (n.lib.neusisOS.mkNeusisFlake { machineRegistries = n.registry.machines; }).nixosConfigurations;
          }
        )).config.flake;

      box = consumer.nixosConfigurations.box.config;
    in
    {
      tests.flake-modules = {
        test-exported-flake-modules = {
          expr = builtins.attrNames self.flakeModules;
          expected = [
            "agenix"
            "darwin-system-defaults"
            "default"
            "lib"
            "options"
          ];
        };

        test-default-module-gives-a-consumer-the-lib-and-integration-modules = {
          expr = {
            lib = lib.sort lib.lessThan (builtins.attrNames consumer.neusis.lib);
            builders = lib.all (n: consumer.neusis.lib.neusisOS ? ${n}) [
              "mkNeusisOS"
              "mkNeusisDarwinOS"
              "mkNeusisFlake"
              "mergeUserConfigs"
            ];
            agnostic = builtins.attrNames consumer.agnosticModules;
            nixosModules = lib.all (n: consumer.nixosModules ? ${n}) [
              "hm-system-init"
              "secrets"
            ];
          };
          expected = {
            lib = [
              "neusisOS"
              "utils"
            ];
            builders = true;
            agnostic = [
              "hm-system-init"
              "secrets"
            ];
            nixosModules = true;
          };
        };

        test-consumer-machine-builds-through-mk-neusis-flake = {
          expr = {
            hosts = builtins.attrNames consumer.nixosConfigurations;
            hostName = box.networking.hostName;
            alice = box.users.users.alice.isNormalUser;
            wheel = builtins.elem "wheel" box.users.users.alice.extraGroups;
            hmUsers = builtins.attrNames box.home-manager.users;
            failed = map (a: a.message) (lib.filter (a: !a.assertion) box.assertions);
          };
          expected = {
            hosts = [ "box" ];
            hostName = "box";
            alice = true;
            wheel = true;
            hmUsers = [ "alice" ];
            failed = [ ];
          };
        };
      };
    };
}
