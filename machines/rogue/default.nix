{
  config,
  pkgs,
  inputs,
  outputs,
  ...
}:
{
  imports = [
    inputs.mac-app-util.darwinModules.default
    inputs.home-manager.darwinModules.home-manager
    inputs.nix-homebrew.darwinModules.nix-homebrew
    #../common/darwin_home_manager.nix
    (import ../common/nix-homebrew.nix {
      inherit inputs;
      user = "ank";
    })
    ../common/nix.nix
    ../common/substituters.nix
  ];

  # Configure nixpkgs
  nixpkgs = {
    # You can add overlays here
    overlays = builtins.attrValues outputs.overlays;
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
    };
  };

  # Enable apple ssh server
  services.openssh.enable = true;
  services.eternal-terminal.enable = true;

  # Enable sketchy bar
  # services.sketchybar = {
  #   enable = true;
  # };

  fonts.packages = [
    pkgs.nerd-fonts.iosevka
  ];

  nix.linux-builder = {
    enable = true;
    ephemeral = true;
    maxJobs = 10;
    config = {
      virtualisation = {
        darwin-builder = {
          diskSize = 100 * 1024;
          memorySize = 24 * 1024;
        };
        cores = 10;
      };
    };
  };

  nix.settings = {

    trusted-users = [
      "@admin"
      "ank"
    ];
  };

  networking.hostName = "rogue";
  networking.computerName = "rogue";

  # Create users
  users.users.ank = {
    description = "Ankur Kumar";
    home = "/Users/ank";
    createHome = true;
    isHidden = false;
    shell = pkgs.zsh;
    openssh.authorizedKeys.keyFiles = [
      ../../homes/ank/id_rsa.pub
      ../../homes/ank/id_ed25519.pub
    ];
  };

  # This is important! Removing this will break your shell and thus your system
  # This is needed even if you enable zsh in home manager
  programs.zsh.enable = true;

  # Configure homebrew
  homebrew = {
    enable = true;
    masApps = {
      Xcode = 497799835;
      "Microsoft Outlook" = 985367838;
    };
    brews = [
      "felixkratz/formulae/svim"
      "dimentium/autoraise/autoraise"
    ];
    taps = map (key: builtins.replaceStrings [ "homebrew-" ] [ "" ] key) (
      builtins.attrNames config.nix-homebrew.taps
    );
    casks = [
      "fiji"
      "hammerspoon"
      "deskflow"
    ];
    onActivation = {
      cleanup = "uninstall";
      autoUpdate = true;
      upgrade = true;
    };
  };

  # Configure home manager
  home-manager = {
    extraSpecialArgs = { inherit inputs outputs; };
    users.ank = {
      imports = [
        inputs.mac-app-util.homeManagerModules.default
        ../../homes/ank/machines/rogue.nix
      ];
    };
  };

  # age.secrets.tsauthkey.file = ../../secrets/common/persistent_tsauthkey.age;
  # services.tailscale = {
  #   enable = true;
  #   authKeyFile = config.age.secrets.tsauthkey.path;
  # };

  security.pam.services.sudo_local.touchIdAuth = true;
  # sudo with touch id
  system = {

    primaryUser = "ank";
    # remap keys : Caps -> Esc
    keyboard.enableKeyMapping = true;
    keyboard.remapCapsLockToEscape = true;

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
}
