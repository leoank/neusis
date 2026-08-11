# Ank's macOS GUI app set, ported off nix-darwin's `homebrew.casks`
# onto brew-nix via the `flake.homeModules.brew-cask` module. Same
# eleven casks that used to live in `machines/_homebrew.nix`.
#
# If a specific cask refuses to launch from `~/.nix-profile/Applications`,
# remove it from this list and drop it back to the system-level
# `homebrew.casks` array in `_homebrew.nix` — they're not mutually
# exclusive on a per-cask basis.
{ self, ... }:
{
  flake.neusis.users.ank.hmBundles.casks =
    { ... }:
    {
      imports = [ self.homeModules.brew-cask ];

      neusis.brew-cask = {
        enable = true;
        # Two casks live on the system `homebrew.casks`
        # fallback list (see `machines/_homebrew.nix`) because
        # brew-nix can't build them today:
        #
        #   * `deskflow`  — not in brew-nix's brew-api snapshot
        #                   (bump brew-api when upstream catches up).
        #   * `fiji`      — installer-style cask; brew-nix's
        #                   default unpack phase produces no
        #                   output for it.
        #
        # Retry brew-nix for these on each `nix flake update`.
        # (`whatsapp` was a third such cask — now pulled from
        # fresh-apps.nix instead; see `_packages.nix`.)
        casks = [
          # signal now comes from fresh-apps.nix (see _packages.nix)
          "keycastr"
          "hammerspoon"
          "superwhisper"
          "thaw"
          "linearmouse"
          "affinity"
          "whatcable"
        ];
      };
    };
}
