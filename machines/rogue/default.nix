{
  config,
  pkgs,
  inputs,
  outputs,
  lib,
  ...
}:
let
  mkGreedy = caskName: {
    name = caskName;
    greedy = true;
  };
  msgvault = inputs.msgvault.packages.${pkgs.stdenv.hostPlatform.system}.default;
  qmd = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.qmd;
in
{
  imports = [
    inputs.home-manager.darwinModules.home-manager
    inputs.nix-homebrew.darwinModules.nix-homebrew
    (import ../common/nix-homebrew.nix {
      inherit inputs;
      user = "ank";
    })
    ../common/nix.nix
    ../common/substituters.nix
    ../../homes/ank/configs/keyboard/kanata_system.nix
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
      #Xcode = 497799835;
      #"Microsoft Outlook" = 985367838;
    };
    brews = [
      "pixi"
      "gnu-sed"
      "pumas"
      "libusb"
    ];
    taps = map (key: builtins.replaceStrings [ "homebrew-" ] [ "" ] key) (
      builtins.attrNames config.nix-homebrew.taps
    );
    # https://github.com/nix-darwin/nix-darwin/issues/935
    # https://github.com/nix-darwin/nix-darwin/pull/1382
    # greedyCasks = true;
    casks = map mkGreedy [
      "signal"
      "whatsapp"
      "keycastr"
      "fiji"
      "hammerspoon"
      "deskflow"
      "superwhisper"
      "thaw"
      "linearmouse"
      "affinity"
      "whatcable"
    ];
    onActivation = {
      cleanup = "uninstall";
      autoUpdate = true;
      upgrade = true;
    };
  };

  # Configure home manager
  home-manager = {
    useGlobalPkgs = lib.mkForce false;
    extraSpecialArgs = { inherit inputs outputs; };
    users.ank = {
      imports = [
        ../../homes/ank/machines/rogue.nix
      ];
    };
  };

  # Incremental Gmail sync every 15 minutes (syncs all configured accounts)
  # msgvault is managed via Nix flake input; update with: nix flake update msgvault
  launchd.user.agents.msgvault-sync.serviceConfig = {
    ProgramArguments = [
      "${msgvault}/bin/msgvault"
      "sync"
    ];
    StartCalendarInterval = [
      { Minute = 0; }
      { Minute = 15; }
      { Minute = 30; }
      { Minute = 45; }
    ];
    StandardErrorPath = "/tmp/msgvault-sync.err.log";
    StandardOutPath = "/tmp/msgvault-sync.out.log";
  };

  # Hourly qmd re-index + embed (refreshes configured collections)
  launchd.user.agents.qmd-reindex.serviceConfig = {
    ProgramArguments = [
      "${qmd}/bin/qmd"
      "update"
      "&&"
      "${qmd}/bin/qmd"
      "embed"
    ];
    StartCalendarInterval = [
      { Minute = 20; }
    ];
    StandardErrorPath = "/tmp/qmd-reindex.err.log";
    StandardOutPath = "/tmp/qmd-reindex.out.log";
  };

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
