# Neusis hammerspoon home-manager module (Darwin-only).
#
# Ports `homes/ank/configs/hammerspoon/` — an init.lua wiring up the
# PaperWM, ActiveSpace, and SpoonInstall spoons for tiling-window
# management on macOS — into an opt-in home-manager module.
#
# The bundled config + spoons ship next to this file (`./init.lua`
# and `./Spoons/`). Enabling the module symlinks them into
# `~/.hammerspoon/` (hammerspoon's canonical config location). Point
# `configDir` at your own directory to swap the whole config.
#
# This module does NOT install hammerspoon itself — hammerspoon is a
# macOS GUI app. Install it once via `homebrew.casks = [ "hammerspoon" ]`
# in your nix-darwin config (or `brew install --cask hammerspoon`).
{ ... }:
{
  flake.homeModules.hammerspoon =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.neusis.hammerspoon;
    in
    {
      options.neusis.hammerspoon = {
        enable = lib.mkEnableOption ''
          neusis-curated hammerspoon config: PaperWM tiling, ActiveSpace
          space-tracking, SpoonInstall. macOS-only; no-op elsewhere
        '';

        configDir = lib.mkOption {
          type = lib.types.path;
          default = ./.;
          defaultText = lib.literalExpression "./.";
          description = ''
            Directory containing `init.lua` (and optionally a `Spoons/`
            subdirectory) to link into `~/.hammerspoon/`. Defaults to
            the bundled config next to this module. Override to point
            at your own scaffold.
          '';
        };
      };

      config = lib.mkIf (cfg.enable && pkgs.stdenv.isDarwin) {
        home.file.".config/hammerspoon" = {
          source = cfg.configDir;
          recursive = true;
        };
      };
    };
}
