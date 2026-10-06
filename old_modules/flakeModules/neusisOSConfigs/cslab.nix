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
    oppy = self.lib.neusisOS.mkNeusisOS {
      machineName = "oppy";
      userModule = ../../machines/oppy;
      specialArgs = { inherit (self) inputs outputs; };
      userConfig = import ../../users/cslab.nix { pkgs = machinesRegistry.oppy; };
      homeManager = true;
    };

    karkinos = self.lib.neusisOS.mkNeusisOS {
      machineName = "karkinos";
      userModule = ../../machines/karkinos;
      specialArgs = { inherit (self) inputs outputs; };
      userConfig = import ../../users/cslab_karkinos.nix { pkgs = machinesRegistry.karkinos; };
      homeManager = true;
    };

  };
}
