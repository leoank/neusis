# Tests for flake.neusis.features.darwin.system-defaults.
{ self, ... }:
{
  perSystem =
    { ... }:
    let
      t = self.neusis.lib.tests;
      cfg = t.evalDarwin { modules = [ self.neusis.features.darwin.system-defaults ]; };
      d = cfg.system.defaults;
    in
    {
      tests.feature-darwin-system-defaults = {
        test-dock-finder-and-global-defaults = {
          expr = {
            touchId = cfg.security.pam.services.sudo_local.touchIdAuth;
            verifyNixPath = cfg.system.checks.verifyNixPath;
            stateVersion = cfg.system.stateVersion;
            dock = {
              inherit (d.dock)
                autohide
                orientation
                tilesize
                show-recents
                ;
            };
            finder = {
              inherit (d.finder) AppleShowAllFiles FXPreferredViewStyle CreateDesktop;
            };
            extensions = d.NSGlobalDomain.AppleShowAllExtensions;
            pressAndHold = d.NSGlobalDomain.ApplePressAndHoldEnabled;
            screenshots = "${d.screencapture.location}:${d.screencapture.type}";
            spansDisplays = d.spaces.spans-displays;
            hammerspoon = d.CustomUserPreferences."org.hammerspoon.Hammerspoon".MJConfigFile;
            noAds = d.CustomUserPreferences."com.apple.AdLib".allowApplePersonalizedAdvertising;
            failed = t.failedAssertions cfg;
          };
          expected = {
            touchId = true;
            verifyNixPath = false;
            stateVersion = 5;
            dock = {
              autohide = true;
              orientation = "left";
              tilesize = 48;
              show-recents = false;
            };
            finder = {
              AppleShowAllFiles = true;
              FXPreferredViewStyle = "Nlsv";
              CreateDesktop = false;
            };
            extensions = true;
            pressAndHold = false;
            screenshots = "~/Pictures:png";
            spansDisplays = true;
            hammerspoon = "~/.config/hammerspoon/init.lua";
            noAds = false;
            failed = [ ];
          };
        };
      };
    };
}
