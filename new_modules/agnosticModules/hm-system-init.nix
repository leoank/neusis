# Neusis home-manager system integration.
# Flake-parts module that registers an agnostic module at
# `flake.agnosticModules.hm-system-init`. `re-export-all.nix` mirrors it
# into `flake.nixosModules.hm-system-init` and
# `flake.darwinModules.hm-system-init`, so the same wiring works on
# both NixOS and nix-darwin. The module auto-populates
# `home-manager.users.<name>` from the supplied user registries by
# reading each user's `machineToBundlesMap.<hostname>` module list.
#
# NOTE: this file declares no `flake-file.inputs`. It is part of
# `flakeModules.default`, which non-dendritic (plain flake-parts)
# consumers import — and they have no `flake-file` option. neusis's own
# `home-manager` input is declared in `homeModules/home-manager.nix`;
# downstream consumers declare their own `home-manager` input directly.
{ ... }:
{
  flake.agnosticModules.hm-system-init =
    {
      config,
      lib,
      inputs,
      outputs ? inputs.self,
      ...
    }:
    with lib;
    let
      cfg = config.neusis.services.hm-system-init;

      # NOTE: this module deliberately does NOT import home-manager's
      # nixos/darwin flake module — that's platform-specific and reading
      # `pkgs.stdenv.isDarwin` here (or any config-derived value) inside
      # `imports` produces an infinite recursion. The platform-correct
      # home-manager module is added by `mkNeusisOS`/`mkNeusisDarwinOS`
      # before this one, so `home-manager.users.<name>` is already a
      # known option by the time `config` below is evaluated.

      # Flatten admin/regular/locked/guest lists into a single user list.
      allUsersFromRegistry =
        registry:
        registry.admins ++ registry.regulars ++ (registry.locked or [ ]) ++ registry.guests;

      allUsers = concatMap allUsersFromRegistry cfg.userRegistries;

      # One neusis user → `nameValuePair <username> { imports = …; }`,
      # or null when this user has no bundles mapped to the current
      # host in `machineToBundlesMap`.
      mkHmEntry =
        userCfg:
        let
          modules = userCfg.machineToBundlesMap.${config.networking.hostName} or null;
        in
        if modules == null then null else nameValuePair userCfg.username { imports = modules; };

      hmUsers = listToAttrs (filter (e: e != null) (map mkHmEntry allUsers));
    in
    {
      options.neusis.services.hm-system-init = {
        enable = mkEnableOption "neusis-managed home manager system integration";
        userRegistries = mkOption {
          type = types.listOf types.attrs;
          default = [ ];
          example = literalExpression "[ config.flake.neusis.registry.users.anklab ]";
          description = ''
            User registries used on this machine. Every user across the
            listed registries gets a `home-manager.users.<name>` entry
            built from their `machineToBundlesMap.<hostname>` modules.

            Note: System users must still be created separately (e.g. via
            `mkAdmin`/`mkRegular`) — this module only wires up
            home-manager.
          '';
        };
        defaultStateVersion = mkOption {
          type = types.str;
          default = "25.11";
          example = "24.11";
          description = ''
            Default `home.stateVersion` applied to every user's
            home-manager configuration via `home-manager.sharedModules`.
            Bundles can still override per-user by setting
            `home.stateVersion` explicitly. Pin to the release that
            matches the flake's `home-manager` input.
          '';
        };
      };

      config = mkIf cfg.enable {
        home-manager = {
          useGlobalPkgs = mkForce false;
          extraSpecialArgs = { inherit inputs outputs; };
          users = hmUsers;
          sharedModules = [
            { home.stateVersion = mkDefault cfg.defaultStateVersion; }
          ];
        };
      };
    };
}
