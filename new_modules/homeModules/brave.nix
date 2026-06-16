# Neusis brave-browser home-manager module.
#
# Wraps `programs.chromium` with brave as the underlying package
# and a starter set of extensions (ublock, dark reader, kagi
# search, a theme). Per-platform notes:
#
#   * Linux  — `programs.chromium` installs brave-browser-bin from
#              nixpkgs and writes its preferences/extensions config
#              the standard way.
#   * Darwin — home-manager's chromium module CAN install brave on
#              macOS via the same package, but most macOS users
#              prefer the homebrew cask. The module just installs
#              the package + writes prefs; if you want the cask,
#              flip `useHomebrew = true` and add `brave-browser` to
#              the system's `homebrew.casks` list.
#
# Extensions list lives here so it's the same on every machine
# that enables this module.
{ ... }:
{
  flake.homeModules.brave =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.neusis.brave;
    in
    {
      options.neusis.brave = {
        enable = lib.mkEnableOption ''
          brave browser (via `programs.chromium`) with a curated
          extension set
        '';

        useHomebrew = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            On Darwin, prefer the homebrew cask over the nixpkgs
            package. If true, this module skips installing brave
            via home-manager and only writes the extensions /
            preferences — the cask must be in your system's
            `homebrew.casks` list separately.
          '';
        };

        extraExtensions = lib.mkOption {
          type = lib.types.listOf (lib.types.submodule {
            options.id = lib.mkOption {
              type = lib.types.str;
              description = "Chrome Web Store extension ID (32 chars).";
            };
          });
          default = [ ];
          description = ''
            Extensions to install in addition to the kalam defaults
            (ublock origin, dark reader, into-the-black-hole theme,
            kagi search).
          '';
        };

        extraCommandLineArgs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Extra flags passed to the brave binary.";
        };
      };

      config = lib.mkIf cfg.enable {
        programs.chromium = {
          enable = true;

          # On Darwin with `useHomebrew = true`, skip the package
          # so home-manager only manages preferences. The cask
          # provides the binary.
          package = lib.mkIf (!(pkgs.stdenv.isDarwin && cfg.useHomebrew)) pkgs.brave;

          extensions = [
            { id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; } # ublock origin
            { id = "eimadpbcbfnmbkopoojfekhnkhdbieeh"; } # dark reader
            { id = "faeadnfmdfamenfhaipofoffijhlnkif"; } # into the black hole theme
            { id = "cdglnehniifkbagbbombnjghhcihifij"; } # kagi search
          ]
          ++ cfg.extraExtensions;

          commandLineArgs = [
            # macOS audio: stops brave from auto-adjusting input
            # volume during meetings, which can collide with other
            # apps' VAD settings.
            "--disable-features=WebRtcAllowInputVolumeAdjustment"
          ]
          ++ cfg.extraCommandLineArgs;
        };
      };
    };
}
