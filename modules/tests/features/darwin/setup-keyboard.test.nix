# Tests for flake.neusis.features.darwin.setup-keyboard: caps→esc plus
# kanata with the bundled layout.
{ self, ... }:
{
  perSystem =
    { lib, ... }:
    let
      t = self.neusis.lib.tests;
      cfg = t.evalDarwin { modules = [ self.neusis.features.darwin.setup-keyboard ]; };
    in
    {
      tests.feature-darwin-setup-keyboard = {
        test-caps-to-escape-and-kanata = {
          expr = {
            keyMapping = cfg.system.keyboard.enableKeyMapping;
            capsToEsc = cfg.system.keyboard.remapCapsLockToEscape;
            kanata = cfg.neusis.services.kanata.enable;
            keyboards = builtins.attrNames cfg.neusis.services.kanata.keyboards;
            daemon = cfg.launchd.daemons ? kanata-default;
            failed = t.failedAssertions cfg;
          };
          expected = {
            keyMapping = true;
            capsToEsc = true;
            kanata = true;
            keyboards = [ "default" ];
            daemon = true;
            failed = [ ];
          };
        };
      };
    };
}
