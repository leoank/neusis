{
  self,
  ...
}:
let
  deploy = self.neusis.lib.neusisOS.mkNeusisFlake {
    machineRegistries = self.neusis.registry.machines;
  };
in
{
  flake.nixosConfigurations = deploy.nixosConfigurations;
  flake.darwinConfigurations = deploy.darwinConfigurations;
  flake.homeConfigurations = deploy.homeConfigurations;
}
