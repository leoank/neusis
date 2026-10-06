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
          description = "Home user public key — rekeyed secrets are encrypted to it.";
        };
        masterIdentities = mkOption {
          type = types.listOf types.raw;
          # No default — the consumer states its own master identity
          # (whose private half decrypts every rekeyFile).
          example = literalExpression ''
            [ { identity = "/Users/you/.ssh/id_ed25519"; pubkey = "ssh-ed25519 AAAA... you@host"; } ]
          '';
          description = ''
            agenix-rekey master identities used to decrypt rekeyFiles and
            re-encrypt them on `agenix rekey`. Prefer the
            `{ identity; pubkey; }` form with `identity` as a STRING path
            to the private key, so it is read at rekey time and never
            copied into the nix store.
          '';
        };
      };

      config = lib.mkIf cfg.enable {

        # Configure agenix
        age.rekey = {
          # agenix-rekey calls the target pubkey `hostPubkey` in every
          # context (there is no `userPubkey`); for a home config it's the
          # user's key.
          hostPubkey = cfg.userPubkey;
          masterIdentities = cfg.masterIdentities;
          storageMode = "local";
          # Home configs have no `networking.hostName`; key the store by
          # user instead (works in both integrated and standalone HM).
          localStorageDir = ../secrets/rekeyed + "/hm/${config.home.username}";
        };

      };
    };
}
