{
  self,
  lib,
  ...

}:
let
  machinesRegistry = import ../../machines/registry.nix {
    inherit lib;
    nixpkgs = self.inputs.nixpkgs;
    overlays = self.outputs.overlays;
  };
in
{
  config.flake.nixosConfigurations = {
    chiral = self.lib.neusisOS.mkNeusisOS {
      machineName = "chiral";
      userModule = ../../machines/chiral;
      specialArgs = { inherit (self) inputs outputs; };
      userConfig = import ../../users/ank.nix { pkgs = machinesRegistry.chiral; };
      homeManager = true;
    };
  };

  config.flake.darwinConfigurations = {
    darwin001 = self.lib.neusisOS.mkNeusisDarwinOS {
      machineName = "darwin001";
      # Not using the userConfig and directly creating user in the config
      userModule = ../../machines/darwin001;
      specialArgs = { inherit (self) inputs outputs; };
      homeManager = true;
    };

    rogue = self.lib.neusisOS.mkNeusisDarwinOS {
      machineName = "rogue";
      # Not using the userConfig and directly creating user in the config
      userModule = ../../machines/rogue;
      specialArgs = { inherit (self) inputs outputs; };
      homeManager = true;
    };
  };
}
