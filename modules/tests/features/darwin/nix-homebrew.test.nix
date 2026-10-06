# Tests for flake.neusis.features.darwin.nix-homebrew: declarative taps
# for the primary user, immutable.
{ self, ... }:
{
  perSystem =
    { lib, ... }:
    let
      t = self.neusis.lib.tests;
      cfg = t.evalDarwin { modules = [ self.neusis.features.darwin.nix-homebrew ]; };
    in
    {
      tests.feature-darwin-nix-homebrew = {
        test-taps-for-the-primary-user = {
          expr = {
            on = cfg.nix-homebrew.enable;
            user = cfg.nix-homebrew.user;
            taps = builtins.attrNames cfg.nix-homebrew.taps;
            mutable = cfg.nix-homebrew.mutableTaps;
            autoMigrate = cfg.nix-homebrew.autoMigrate;
            failed = t.failedAssertions cfg;
          };
          expected = {
            on = true;
            user = "alice";
            taps = [
              "darrylmorley/homebrew-whatcable"
              "deskflow/homebrew-tap"
              "graelo/homebrew-tap"
              "homebrew/homebrew-cask"
              "homebrew/homebrew-core"
            ];
            mutable = false;
            autoMigrate = true;
            failed = [ ];
          };
        };
      };
    };
}
