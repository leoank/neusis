# Tests for flake.neusis.features.darwin.theme: the system nerd font.
{ self, ... }:
{
  perSystem =
    { lib, ... }:
    let
      t = self.neusis.lib.tests;
      cfg = t.evalDarwin { modules = [ self.neusis.features.darwin.theme ]; };
    in
    {
      tests.feature-darwin-theme = {
        test-installs-iosevka-nerd-font = {
          expr = lib.any (lib.hasInfix "iosevka") (t.pkgNames cfg.fonts.packages);
          expected = true;
        };
      };
    };
}
