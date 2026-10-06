{
  inputs,
  self,
  ...
}:
{
  flake.nixosConfigurations.myhost = self.neusis.lib.neusisOS.mkNeusisOS {
    machineName = "myhost";

    # The machine module. neusis seeds every login account's password from
    # an agenix secret, so the host needs the agenix module too.
    userModule = {
      imports = [
        ../machine.nix
        inputs.neusis.inputs.agenix.nixosModules.default
      ];
    };

    # Forwarded to both the NixOS module evaluation and home-manager's
    # `extraSpecialArgs`. Pass `self` and `inputs` so machine/home
    # modules can reach other flake outputs.
    specialArgs = { inherit self inputs; };

    # Creates the system accounts for every user in these registries and
    # wires up home-manager for them (from each user's
    # `machineToBundlesMap.myhost`).
    userRegistries = [ self.neusis.registry.users.myLab ];

    # Required whenever a host has login users. Point it at your own
    # agenix secret — neusis deliberately has no default.
    initialHashedPassword = ../secrets/hashedInitialPassword.age;
  };
}
