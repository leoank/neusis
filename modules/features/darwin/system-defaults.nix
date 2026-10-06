{ ... }:
{
  flake.neusis.features.darwin.system-defaults =
    { ... }:
    {
      # sudo with touch id
      security.pam.services.sudo_local.touchIdAuth = true;

      # `system.primaryUser` is now set per-machine by
      # `mkNeusisDarwinOS` from `machineType.primaryUser`. No need to
      # re-set it here.
      system = {

        # Turn off NIX_PATH warnings now that we're using flakes
        checks.verifyNixPath = false;

        stateVersion = 5;

        defaults = {

          NSGlobalDomain = {
            AppleShowAllExtensions = true;
            # Disable press and hold for diacritics.
            # I want to be able to press and hold j and k
            # in vim to move around.
            ApplePressAndHoldEnabled = false;
          };

          dock = {
            autohide = true;
            show-recents = false;
            launchanim = true;
            orientation = "left";
            tilesize = 48;
            mru-spaces = false;
          };

          screencapture = {
            location = "~/Pictures";
            type = "png";
          };

          finder = {
            AppleShowAllFiles = true;
            ShowStatusBar = true;
            ShowPathbar = true;
            FXDefaultSearchScope = "SCcf";
            # "icnv" = Icon view, "Nlsv" = List view, "clmv" = Column View, "Flwv" = Gallery View
            FXPreferredViewStyle = "Nlsv";
            AppleShowAllExtensions = true;
            CreateDesktop = false;
            ShowExternalHardDrivesOnDesktop = false;
            ShowHardDrivesOnDesktop = false;
            ShowMountedServersOnDesktop = false;
            ShowRemovableMediaOnDesktop = false;
            FXEnableExtensionChangeWarning = false;
          };

          # Required for paperWM
          spaces.spans-displays = true;

          CustomUserPreferences = {

            NSGlobalDomain = {
              WebKitDevelopersExtras = true;
              AppleHighlightColor = "0.615686 0.823529 0.454902";
            };

            "com.apple.desktopservices" = {
              # Avoid creating .DS_Store files on network or USB volumes
              DSDontWriteNetworkStores = true;
              DSDontWriteUSBStores = true;
            };

            "com.apple.AdLib" = {
              allowApplePersonalizedAdvertising = false;
            };

            "com.apple.print.PrintingPrefs" = {
              # Automatically quit printer app once the print jobs complete
              "Quit When Finished" = true;
            };

            # Prevent Photos from opening automatically when devices are plugged in
            "com.apple.ImageCapture".disableHotPlug = true;

            "org.hammerspoon.Hammerspoon" = {
              MJConfigFile = "~/.config/hammerspoon/init.lua";
            };

          };

        };
      };

    };

}
