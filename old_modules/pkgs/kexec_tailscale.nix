{
  pkgs,
  inputs,
  outputs,
  ...
}:
let
  modules = [
    inputs.nixos-images.nixosModules.kexec-installer
    inputs.nixos-images.nixosModules.noninteractive
    inputs.agenix.nixosModules.default
    outputs.nixosModules.tailscale
    ../machines/oppy/network.nix
    {
      system.kexec-installer.name = "nixos-kexec-installer-noninteractive";

      # Disable bcachefs - not needed and works around nixpkgs bug with bcachefs-tools
      boot.supportedFilesystems.bcachefs = false;
      
      # SSH configuration for kexec installer
      services.openssh.settings.PermitRootLogin = "yes";
      
      neusis.tailscale = {
        enable = true;
        isPersistent = true;
        hostName = "oppy";
        forceHostName = true;
        persistent_authkey_file = ../secrets/common/persistent_cslab_mesh.age;
        clientIdFile = ../secrets/common/tsclient.age;
        clientSecretFile = ../secrets/common/tssecret.age;
        disableKeyExpiry = true;
        tailnetOrg = "shntnu.github";
      };      
    }
  ];
in
(pkgs.nixos modules).config.system.build.kexecInstallerTarball
