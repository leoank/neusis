# Neusis secrets service (agenix-rekey).
#
# Registered at `flake.agnosticModules.secrets` and re-exported to
# `flake.nixosModules.secrets` / `flake.darwinModules.secrets`.
#
# NOTE: the platform-correct agenix + agenix-rekey modules are imported
# by the machine (they can't be branched here — importing
# `nixosModules` into a darwin config breaks), so a consumer imports:
#   inputs.agenix.darwinModules.default
#   inputs.agenix-rekey.darwinModules.default
#   self.darwinModules.secrets           (or the nixos equivalents)
# and sets `neusis.services.secrets.{enable,hostPubkey,masterIdentities,storageBaseDir}`.
{ ... }:
{
  flake.agnosticModules.secrets =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    with lib;
    let
      cfg = config.neusis.services.secrets;
    in
    {
      options.neusis.services.secrets = {
        enable = mkEnableOption "neusis-managed secrets service";

        hostPubkey = mkOption {
          type = types.str;
          example = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOy3dC8cCbuc...";
          description = "This host's SSH public key — agenix-rekey encrypts this host's secrets to it.";
        };

        masterIdentities = lib.mkOption {
          type = types.listOf types.raw;
          # No default on purpose — the consumer must state its own
          # master identity (whose private half decrypts every secret).
          example = lib.literalExpression ''
            [ { identity = "/Users/you/.ssh/id_ed25519"; pubkey = "ssh-ed25519 AAAA... you@host"; } ]
          '';
          description = ''
            agenix-rekey master identities — the key(s) used to decrypt
            rekeyFiles and re-encrypt them per host on `agenix rekey`.
            Set explicitly by the consumer. Prefer the
            `{ identity; pubkey; }` form with `identity` as a STRING path
            to the private key, so it is read at rekey time on the
            operator's machine and never copied into the nix store.
          '';
        };

        rootUserPassPath = mkOption {
          type = types.nullOr types.path;
          default = null;
          example = "../secrets/common/hashedInitialPassword.age";
          description = "rekeyFile holding the root password hash. NixOS only; ignored on darwin.";
        };

        storageBaseDir = mkOption {
          type = types.path;
          example = literalExpression "../secrets/rekeyed";
          description = ''
            Base directory under which agenix-rekey stores each host's
            rekeyed secrets (`storageMode = "local"`). The effective
            `age.rekey.localStorageDir` is `storageBaseDir/<hostname>`.

            No default: a path inside the consumer's own repo, so rekeyed
            outputs land in their tree (a default would point into
            neusis's source).
          '';
        };

        remoteBuildKeyFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          example = literalExpression "../secrets/common/remote-build-key.age";
          description = ''
            rekeyFile for the shared distributed-build SSH key, exposed
            as `age.secrets.remoteBuildKey` at `/etc/nix/remote-build-key`
            (consumed by the build-client feature). `null` (the default)
            declares no such secret: a consumer names its own key, and
            neusis's distributed-builds feature sets neusis's.
          '';
        };
      };

      config = mkIf cfg.enable (mkMerge [
        {
          age.rekey = {
            hostPubkey = cfg.hostPubkey;
            masterIdentities = cfg.masterIdentities;
            storageMode = "local";
            localStorageDir = cfg.storageBaseDir + "/${config.networking.hostName}";
          };
        }

        # Shared build-user private key for nix distributed builds
        # (consumed by build-client's `sshKey`), when one is named.
        (mkIf (cfg.remoteBuildKeyFile != null) {
          age.secrets.remoteBuildKey = {
            rekeyFile = cfg.remoteBuildKeyFile;
            path = "/etc/nix/remote-build-key";
            mode = "0400";
            owner = "root";
          };
        })

        # Root password is a NixOS concept; nix-darwin manages root
        # differently, so only wire it on Linux.
        (mkIf (pkgs.stdenv.isLinux && cfg.rootUserPassPath != null) {
          age.secrets.neusis-root-pw-hash.rekeyFile = cfg.rootUserPassPath;
          users.users.root.hashedPasswordFile = config.age.secrets.neusis-root-pw-hash.path;
        })
      ]);
    };
}
