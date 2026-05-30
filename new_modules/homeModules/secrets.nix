# Neusis secrets service (home-manager).
# Flake-parts module that registers a home-manager module at
# `flake.homeModules.secrets` exposing `neusis.service.secrets.enable`.
# Import from a home-manager configuration to opt the user into
# neusis-managed secrets handling.
{ ... }:
{
  flake.homeModules.secrets =
    {
      config,
      lib,
      inputs,
      ...
    }:
    with lib;
    let
      cfg = config.neusis.service.secrets;
    in
    {
      # Import agenix and agenix-rekey modules
      imports = [
        inputs.agenix.homeManagerModules.default
        inputs.agenix-rekey.homeManagerModules.default
      ];
      options.neusis.service.secrets = {
        enable = lib.mkEnableOption "neusis-managed secrets service";
        userPubkey = mkOption {
          type = types.str;
          example = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOy3dC8cCbucumHphroUzZUTKkM0jL3mG3+tkeAWgIdX";
          description = "Home user public key";
        };
      };

      config = lib.mkIf cfg.enable {

        # Configure agenix
        age.rekey = {
          userPubkey = cfg.userPubkey;
          masterIdentities = [ cfg.userPubkey ];
          storageMode = "local";
          localStorageDir = ./. + "/secrets/rekeyed/${config.networking.hostName}/hm";
        };

      };
    };
}
