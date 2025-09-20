{
  inputs,
  outputs,
  ...
}:
{
  imports = [
    inputs.hardware.nixosModules.common-pc-ssd
    inputs.home-manager.nixosModules.home-manager
    inputs.agenix.nixosModules.default
    outputs.nixosModules.tailscale

    ./hardware-configuration.nix

    # boot config
    ./boot.nix

    # Disko configuration
    inputs.disko.nixosModules.disko
    ./disko.nix

    # oppy networking config
    ./network.nix

    # oppy misc
    ./misc.nix

    # vm stuff
    ./vm.nix

    #  common config
    ../common/networking.nix
    ../common/gpu/nvidia_dc.nix
    ../common/substituters.nix
    ../common/virtualization.nix
    ../common/input_device.nix
    ../common/ssh.nix
    ../common/us_eng.nix
    ../common/nosleep.nix
    ../common/nix.nix
    ../common/printing.nix
    ../common/zfs.nix
    ../common/comin.nix

  ];

  neusis.tailscale = {
    enable = true;
    isPersistent = true;
    hostName = "oppy";
    forceHostName = true;
    persistent_authkey_file = ../../secrets/common/persistent_cslab_mesh.age;
    clientIdFile = ../../secrets/common/persistent_tsapiid.age;
    clientSecretFile = ../../secrets/common/persistent_tsapikey.age;
    disableKeyExpiry = true;
    tailnetOrg = "shntnu.github";
  };
  
  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.05";
}
