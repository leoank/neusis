# Neusis secrets service (home-manager).
# Flake-parts module that registers a home-manager module at
# `flake.homeModules.secrets`. Importing it opts the user into
# neusis-managed secrets handling: it pulls in agenix + agenix-rekey, and
# agenix-rekey requires `age.rekey.masterIdentities` whenever it is
# loaded, so the module cannot be imported and left disabled. `enable`
# therefore defaults to `true`; setting it to `false` fails with a clear
# assertion instead of agenix-rekey's.
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
        enable = mkOption {
          type = types.bool;
          default = true;
          description = ''
            Whether neusis manages this home's secrets. Defaults to `true`
            because importing this module already loads agenix-rekey, which
            must be configured; to opt out, drop the import rather than
            setting this to `false`.
          '';
        };
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

      config = mkMerge [
        {
          assertions = [
            {
              assertion = cfg.enable;
              message = ''
                neusis.service.secrets cannot be disabled once imported: the
                agenix-rekey module it pulls in requires rekey configuration.
                Remove `self.homeModules.secrets` from the imports instead.
              '';
            }
          ];
        }

        (lib.mkIf cfg.enable {
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
        })
      ];
    };
}
