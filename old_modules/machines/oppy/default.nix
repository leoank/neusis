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

    # System configuration
    ./boot.nix
    ./network.nix
    ./system.nix
    ./packages.nix
    ./services.nix
    ./ollama.nix

    # Deployment configs
    inputs.disko.nixosModules.disko
    ./deployment/disko.nix
    ./deployment/vm.nix

    # CSLab infrastructure and monitoring
    outputs.nixosModules.cslab-infrastructure
    outputs.nixosModules.cslab-monitoring

    # Common config
    ../common/system.nix
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
    outputs.nixosModules.zfs
    ../common/sudo.nix

  ];

  neusis.tailscale = {
    enable = true;
    isPersistent = true;
    hostName = "oppy";
    forceHostName = true;
    persistent_authkey_file = ../../secrets/common/persistent_cslab_mesh.age;
    clientIdFile = ../../secrets/common/tsclient.age;
    clientSecretFile = ../../secrets/common/tssecret.age;
    disableKeyExpiry = true;
    tailnetOrg = "shntnu.github";
  };

  neusis.cslab.infrastructure = {
    enable = true;
    userConfigPath = ../../users/cslab.nix;
    testScriptPath = ./cslab/scripts/test-cslab-infrastructure.sh;
    # dataRoot defaults to "/work" — correct for Oppy
    # imagingGid defaults to 1000 — correct for Oppy
  };

  neusis.cslab.monitoring = {
    enable = true;
    userConfigPath = ../../users/cslab.nix;
    machineName = "Oppy";
    slackWebhookSecretFile = ../../secrets/oppy/slack_webhook.age;
    quotaCheckScript = ../../modules/nixos/cslab-scripts/check-quotas.nu;
    # quotaLimit defaults to 100 — correct for Oppy
    # homeBaseDir defaults to "/home" — correct for Oppy
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.11";
}
