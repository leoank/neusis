# Neusis brew-cask home-manager module — homebrew casks as Nix
# packages via brew-nix (BatteredBunny/brew-nix).
#
# Why this and not nix-darwin's `homebrew.casks`?
#
#   * Casks become reproducible — hash-pinned tarballs, not "whatever
#     brew downloads at activation time".
#   * No homebrew binary or runtime needed on the host — brew-nix
#     just fetches the same upstream cask URLs and unpacks them.
#   * Lives in home-manager, so casks are per-user rather than
#     per-system (matches how GUI apps are actually scoped on
#     macOS in practice).
#
# Caveats (from the upstream README — not theoretical):
#
#   * Darwin only — Linux hosts get a no-op.
#   * Some apps refuse to launch from `~/.nix-profile/Applications`
#     (the location home-manager places casks on darwin). Apps
#     that register privileged helpers, Accessibility hooks, or
#     Launch Services entries are the usual offenders (e.g.
#     Hammerspoon, Signal). If one of yours misbehaves, fall back
#     to the system-level `homebrew.casks` list for THAT cask.
#   * ~700 upstream casks lack hashes and fail to build without a
#     manual override. If `nix build` fails on a specific cask,
#     either pin via an overlay (`pkgs.brewCasks = prev.brewCasks //
#     { foo = prev.brewCasks.foo.override { hash = "..."; }; }`) or
#     drop it back to the system homebrew list.
#   * `nix run` doesn't work for most casks — they must be built
#     into the profile (which `home.packages` does) and launched
#     from the App or via Spotlight, not via `nix run`.
{ inputs, ... }:
{
  # brew-nix needs `brew-api` (the JSON cask index) declared
  # separately and followed in, otherwise it uses a stale version.
  flake-file.inputs = {
    brew-nix = {
      url = "github:BatteredBunny/brew-nix";
      inputs.brew-api.follows = "brew-api";
    };
    brew-api = {
      url = "github:BatteredBunny/brew-api";
      flake = false;
    };
  };

  flake.homeModules.brew-cask =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.neusis.brew-cask;
    in
    {
      options.neusis.brew-cask = {
        enable = lib.mkEnableOption ''
          homebrew casks installed via brew-nix instead of
          nix-darwin's `homebrew.casks` — reproducible, no `brew`
          binary needed at activation. Darwin only.
        '';

        casks = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [
            "signal"
            "whatsapp"
            "linearmouse"
          ];
          description = ''
            Cask names to install. Each is looked up as
            `pkgs.brewCasks.<name>`; unknown names error at eval
            time (intentional — fail loudly rather than silently
            skip a missing app).
          '';
        };
      };

      # NB: don't gate this `mkIf` on `pkgs.stdenv.isDarwin` — `pkgs`
      # is derived from the `nixpkgs.{overlays,config}` we set
      # below, so reading it here causes an infinite recursion in
      # the module fixed-point. Caller is responsible for only
      # enabling on darwin (the option description says so).
      # home-manager runs with `useGlobalPkgs = mkForce false`
      # (see `agnosticModules/hm-system-init.nix`), so this
      # overlay applies to the same `pkgs` argument that
      # `lib.attrVals` reads from below.
      config = lib.mkIf cfg.enable {
        nixpkgs.overlays = [ inputs.brew-nix.overlays.default ];
        # Most casks are unfree (commercial macOS apps); the
        # system pkgs already sets this, but home-manager's own
        # nixpkgs instance defaults to closed, so set explicitly.
        nixpkgs.config.allowUnfree = true;

        home.packages = lib.attrVals cfg.casks pkgs.brewCasks;
      };
    };
}
