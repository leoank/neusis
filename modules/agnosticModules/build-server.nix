# Distributed builds — SERVING side (agnostic module).
#
# Re-exported to `self.nixosModules.build-server` and
# `self.darwinModules.build-server`. Import it on any machine that should
# act as a remote builder, then configure via `neusis.services.build-server`:
#
#   imports = [ self.darwinModules.build-server ];
#   neusis.services.build-server = {
#     enable = true;
#     authorizedKeyFiles = [ ../secrets/common/remote-build.pub ];
#   };
#
# It creates a dedicated, nix-trusted build user whose authorized_keys
# hold the shared build PUBLIC key. Self-contained — no registry or
# flake-level data required, so it's reusable on its own.
{ ... }:
{
  flake.agnosticModules.build-server =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.neusis.services.build-server;
    in
    {
      options.neusis.services.build-server = {
        enable = lib.mkEnableOption "nix distributed-builds serving side (dedicated build user)";

        user = lib.mkOption {
          type = lib.types.str;
          default = "nixremote";
          description = "Name of the dedicated, nix-trusted build user created on this builder.";
        };

        uid = lib.mkOption {
          type = lib.types.int;
          default = 601;
          description = ''
            uid for the build user. Only used on nix-darwin (which needs
            an explicit uid to create the account); ignored on NixOS,
            where the user is a dynamically-allocated system user.
          '';
        };

        authorizedKeyFiles = lib.mkOption {
          type = lib.types.listOf lib.types.path;
          default = [ ];
          example = lib.literalExpression "[ ../secrets/common/remote-build.pub ]";
          description = "Public-key files added to the build user's authorized_keys.";
        };

        authorizedKeys = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Inline public-key strings added to the build user's authorized_keys.";
        };

        trust = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Add the build user to `nix.settings.trusted-users`.";
        };
      };

      config = lib.mkIf cfg.enable (lib.mkMerge [
        {
          nix.settings.trusted-users = lib.mkIf cfg.trust [ cfg.user ];
          users.users.${cfg.user}.openssh.authorizedKeys = {
            keyFiles = cfg.authorizedKeyFiles;
            keys = cfg.authorizedKeys;
          };
        }

        (lib.mkIf pkgs.stdenv.isLinux {
          users.users.${cfg.user} = {
            isSystemUser = true;
            group = cfg.user;
            useDefaultShell = true;
          };
          users.groups.${cfg.user} = { };
        })

        (lib.mkIf pkgs.stdenv.isDarwin {
          users.users.${cfg.user} = {
            uid = cfg.uid;
            home = "/Users/${cfg.user}";
            shell = "/bin/zsh";
          };
          # nix-darwin only manages users it's explicitly told to know about.
          users.knownUsers = [ cfg.user ];
        })
      ]);
    };
}
