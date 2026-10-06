{ self, ... }:
let
  # Every lab registry; `all` is their merge (per role).
  userRegistries = with self.neusis.registry.users; [
    cslab
    cslab_karkinos
    anklab
    kumaranklab
  ];
in
{
  flake.neusis.registry.users.all = self.neusis.lib.neusisOS.mergeUserConfigs userRegistries;
}
