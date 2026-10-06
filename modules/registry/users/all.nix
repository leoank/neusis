{ self, ... }:
let
  userRegistries = [
    self.registry.users.cslab
    self.registry.users.cslab_karkinos
    self.registry.users.anklab
  ];
in
{
  flake.neusis.registry.users.all = self.lib.neusisOS.mergeUserConfigs userRegistries;
}
