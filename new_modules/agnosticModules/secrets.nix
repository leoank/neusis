# Neusis secrets service.
# Flake-parts module that registers a NixOS module at
# `flake.nixosModules.secrets` exposing `neusis.service.secrets.enable`.
# Import from a NixOS configuration to opt the host into neusis-managed
# secrets handling.
{ ... }:
{
  flake.agnosticModules.secrets =
    {
      config,
      lib,
      inputs,
      ...
    }:
    with lib;
    let
      cfg = config.neusis.services.secrets;
      keysFromUserRegistries = listOfUserRegitries: listOfUserRegitries;
    in
    {
      imports = [
        inputs.agenix.nixosModules.default
        inputs.agenix-rekey.nixosModules.default
      ];
      options.neusis.services.secrets = {
        enable = mkEnableOption "neusis-managed secrets service";
        hostPubkey = mkOption {
          type = types.str;
          example = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOy3dC8cCbucumHphroUzZUTKkM0jL3mG3+tkeAWgIdX";
          description = "Host public key";
        };
        rootUserPassPath = mkOption {
          type = types.path;
          example = "./neusis-root-user-pass";
          description = "Path to the hashed password for root user";
        };
        userRegistries = mkOption {
          type = types.listOf types.deferredModule;
          example = "[ config.registry.users.anklab ]";
          description = ''
            List of user registries used on this machine. 
            Admins on the list will be added to masterIdentities of agenix-rekey using the sshKeys property.
          '';
        };
      };

      config = mkIf cfg.enable {
        # Import agenix and agenix-rekey modules

        # Configure agenix
        age.rekey = {
          hostPubkey = cfg.hostPubkey;
          masterIdentities = [ ./yubikey-identity.pub ];
          storageMode = "local";
          localStorageDir = ./. + "/secrets/rekeyed/${config.networking.hostName}";
        };

        # Create common secrets for neusis
        age.secrets.neusis-root-pw-hash.rekeyFile = cfg.rootUserPassPath;

        # Configure host with common secrets
        users.users.root.hashedPasswordFile = config.age.secrets.neusis-root-pw-hash.path;
      };
    };
}
