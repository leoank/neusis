{ self, ... }:
let
  userConfigList = [
    (import ./cslab.nix { })
    (import ./cslab_karkinos.nix { })
    (import ./ank.nix { })
  ];
in
self.lib.neusisOS.mergeUserConfigs userConfigList
