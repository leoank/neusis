{
  inputs,
  self,
  ...
}:
{
  flake.nixosConfigurations.myhost = self.neusis.lib.neusisOS.mkNeusisOS {
    machineName = "myhost";
    userModule = ../machine.nix;

    # Forwarded to both the NixOS module evaluation and home-manager's
    # `extraSpecialArgs`. Pass `self` and `inputs` so machine/home
    # modules can reach other flake outputs.
    specialArgs = { inherit self inputs; };

    userConfig = self.neusis.registry.users.myLab;
    homeManager = true;

    # Override the lib's default — it points at a path inside the
    # neusis repo that a consumer can't decrypt.
    initialHashedPassword = ../secrets/hashedInitialPassword.age;
  };
}
