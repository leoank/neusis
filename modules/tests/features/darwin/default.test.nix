# Tests for flake.neusis.features.darwin.defaults: the composition of the
# shared Darwin + agnostic features evaluates without conflicts.
{ self, ... }:
{
  perSystem =
    { lib, ... }:
    let
      t = self.neusis.lib.tests;
      cfg = t.evalDarwin { modules = [ self.neusis.features.darwin.defaults ]; };
    in
    {
      tests.feature-darwin-defaults = {
        test-composes-without-conflicts = {
          expr = {
            dock = cfg.system.defaults.dock.autohide;
            homebrew = cfg.nix-homebrew.enable;
            font = lib.any (lib.hasInfix "iosevka") (t.pkgNames cfg.fonts.packages);
            gc = cfg.nix.gc.automatic;
            overlays = builtins.length cfg.nixpkgs.overlays;
            ssh = cfg.services.openssh.enable;
            failed = t.failedAssertions cfg;
          };
          expected = {
            dock = true;
            homebrew = true;
            font = true;
            gc = true;
            overlays = builtins.length (builtins.attrValues self.overlays);
            ssh = true;
            failed = [ ];
          };
        };

        test-exported-darwin-features = {
          expr = builtins.attrNames self.neusis.features.darwin;
          expected = [
            "defaults"
            "nix-homebrew"
            "setup-keyboard"
            "system-defaults"
            "theme"
            "virtualization"
          ];
        };
      };
    };
}
